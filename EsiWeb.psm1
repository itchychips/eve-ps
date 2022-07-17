# This file is part of Eve-PS.
#
# Eve-PS is free software: you can redistribute it and/or modify it under the
# terms of the GNU Affero Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# Eve-PS is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero Public License for more details.
#
# You should have received a copy of the GNU Affero Public License along with
# Eve-PS. If not, see <https://www.gnu.org/licenses/>.
[CmdletBinding()]
Param(
    [parameter()]
    [switch]$ClearCache
)

Import-Module $PSScriptRoot\EvePsUtil.psm1

$global:EsiBaseUri = "https://esi.evetech.net/latest"

$ErrorActionPreference = "Stop"

Set-StrictMode -Version Latest

[System.Net.ServicePointManager]::SecurityProtocol = "Tls12"

function Register-EsiCache {
    Param(
    )

    $connection = Open-EvePsDataConnection

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        CREATE TABLE IF NOT EXISTS cache_web (
            CacheWebId INTEGER PRIMARY KEY,
            Uri STRING,
            ETag STRING,
            Response STRING,
            Expiry DATETIME
        );"
}

function Unregister-EsiCache {
    Param(
    )

    $connection = Open-EvePsDataConnection

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        DROP TABLE IF EXISTS cache_web;"
}

function Clear-EsiCache {
    [CmdletBinding()]
    Param(
    )

    $connection = Open-EvePsDataConnection

    Register-EsiCache

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        DELETE FROM cache_web;"

    # Cache using: $Cache[$Uri] = $Expiry
    #$global:CacheExpiry = @{}
    ## Cache using: $Cache[$Uri] = $Etag
    #$global:CacheETag = @{}
    ## Cache using: $Cache[$Uri] = $Response
    #$global:CacheResponse = @{}
}

function Get-EsiCacheEntry {
}

$global:LastHeaders = @{}

#if (-not (Test-Path variable:\CacheExpiry) -or $ClearCache) {
#    Clear-EsiCache
#}

function Convert-PSObjectProperty {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory,ValueFromPipeline)]
        [PSObject]$Object
    )
    $output = New-Object -Type PSObject
    foreach ($property in $Object.PSObject.Properties) {
        $propertyName = ""
        $uppercaseNext = $false
        foreach ($character in $property.Name.GetEnumerator()) {
            if ($propertyName -eq "") {
                $propertyName += [char]::ToUpperInvariant($character)
            }
            elseif ($character -eq "_") {
                $uppercaseNext = $true
            }
            elseif ($uppercaseNext) {
                $propertyName += [char]::ToUpperInvariant($character)
                $uppercaseNext = $false
            }
            else {
                $propertyName += $character
            }
        }
        $output | Add-Member -Type NoteProperty -Name $propertyName -Value $property.Value
    }
    $output
}

function Invoke-WebRequest2 {
    [CmdletBinding(DefaultParameterSetName="Body")]
    Param(
        [parameter(Mandatory)]
        [string]$Uri,
        [parameter()]
        [string]$Method="Get",
        #[parameter(ParameterSetName="Body")]
        [parameter(ParameterSetName="Body")]
        [PSObject]$Body,
        [parameter(ParameterSetName="ArrayBody")]
        [PSObject[]]$ArrayBody,
        [parameter()]
        [HashTable]$AdditionalHeaders,
        [parameter()]
        [switch]$IgnorePages,
        [parameter()]
        [switch]$IgnoreExpiry,
        [parameter()]
        [switch]$IgnoreETag
        #[parameter(ParameterSetName="JsonBody")]
        #[string]$JsonBody
    )

    Write-Verbose "$Method on endpoint '$Uri'."

    $connection = Open-EvePsDataConnection

    $result = $null

    $now = Get-Date

    Register-EsiCache

    $cacheEntry = Invoke-SqliteQuery -SqliteConnection $connection -Query "
        SELECT CacheWebId, Response, ETag, Expiry
        FROM cache_web
        WHERE Uri = @Uri;" -SqlParameters @{
            "Uri"=$Uri
        }
    if (-not $IgnoreExpiry -and $cacheEntry -and $cacheEntry.Response -and ($now -lt $cacheEntry.Expiry)) {
        Write-Verbose "Currently before expiry for '$Uri'.  Returning cached response."
        $result = $cacheEntry.Response | ConvertFrom-Json
    }

    if (-not $result) {
        $headers = @{
            "Accept-Language"="en"
            "Content-Type"="application/json"
            "Accept"="application/json"
        }

        if (-not $IgnoreETag -and $cacheEntry -and $cacheEntry.ETag) {
            $headers["If-None-Match"] = $cacheEntry.ETag
        }

        if ($AdditionalHeaders) {
            foreach ($key in $AdditionalHeaders.Keys) {
                $headers[$key] = $AdditionalHeaders[$key]
            }
        }

        $params = @{
            "UseBasicParsing"=$true
            "Headers"=$headers
            "Uri"=$Uri
            "Method"=$Method
        }

        #if ($JsonBody) {
        #    $params["Body"] = $JsonBody
        #}
        if ($Body) {
            $params["Body"] = ConvertTo-Json -InputObject $Body
        }
        elseif ($ArrayBody) {
            $params["Body"] = ConvertTo-Json -InputObject $ArrayBody
        }

        try {
            $retryCount = 0
            while ($true) {
                try {
                    $result = Invoke-WebRequest @params
                }
                catch {
                    Set-StrictMode -Off

                    if ($_.Exception.GetType().Name -eq "FormatException") {
                        throw
                    }
                    elseif ($_.Exception.Response.StatusCode -eq "NotModified") {
                        throw
                    }
                    elseif ($retryCount -lt 3) {
                        # Sometimes intermittent connections can happen.  I've seen a 502 error a few times during these calls, so we'll do some hardcoded retry logic to compensate here.
                        $retryCount++
                        Write-Warning "Error occurred: $_.  Retry $retryCount of 3."
                        continue
                    }
                    throw
                }
                $transformedResult = New-Object -Type PSObject
                $transformedResult | Add-Member -Type NoteProperty -Name "Headers" -Value $result.Headers
                $transformedResult | Add-Member -Type NoteProperty -Name "Content" -Value $result.Content
                $result = $transformedResult | ConvertTo-Json | ConvertFrom-Json
                $global:LastHeaders = $result.Headers
                break
            }
        }
        catch {
            Set-StrictMode -Off
            if ($_.Exception.GetType().Name -eq "UriFormatException") {
                throw
            }

            # For some reason they decided that 304 was an exceptional status...
            # Wonderful.  Spoiler: It's not, and throwing an exception here is
            # incredibly ridiculous.
            if ($_.Exception.Response.StatusCode -ne "NotModified") {
                throw
            }
            Write-Verbose "Got 304 status for '$Uri'.  Using cached response."
            if ($cacheEntry -and $cacheEntry.Response) {
                $result = $cacheEntry.Response | ConvertFrom-Json
            }
            $global:LastHeaders = $_.Exception.Response.Headers
        }
    }

    if (-not $cacheEntry) {
        Invoke-SqliteQuery -SqliteConnection $connection -Query "
            INSERT INTO cache_web (
                Uri,
                Response,
                ETag,
                Expiry
            ) VALUES (
                @Uri,
                NULL,
                NULL,
                NULL
            );" -SqlParameters @{
                "Uri"=$Uri
            }
    }

    if ($result.Headers | Test-Member -MemberName ETag) {
        Invoke-SqliteQuery -SqliteConnection $connection -Query "
            UPDATE cache_web
            SET ETag = @ETag
            WHERE Uri = @Uri;" -SqlParameters @{
                "ETag"=$result.Headers.ETag[0]
                "Uri"=$Uri
            }
    }
    $response = New-Object -Type PSObject
    $response | Add-Member -Type NoteProperty -Name "Headers" -Value $result.Headers
    $response | Add-Member -Type NoteProperty -Name "Content" -Value $result.Content

    # Headers are Dictionary<String,IEnumerable<String>> now, apparently.  not just Dictionary<String,String>
    $expiry = Get-Date $result.Headers.Expires[0] -Format o
    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        UPDATE cache_web
        SET Expiry = @Expiry,
            Response = @Response
        WHERE Uri = @Uri;" -SqlParameters @{
            "Expiry"=$expiry
            "Response"=($response | ConvertTo-Json)
            "Uri"=$Uri
        }

    $output = $result.Content | ConvertFrom-Json
    if ($output.GetType().BaseType.Name -ne "Array") {
        $output | Convert-PSObjectProperty
    }
    else {
        $output
    }

    if (($result.Headers | Test-Member -MemberName "X-Pages") -and -not $IgnorePages) {
        Write-Verbose "X-Pages header present for '$Uri'.  Getting everything."
        $currentPage = 2
        [int]$maxPage = $result.Headers."X-Pages"[0]
        for ($currentPage = 2; $currentPage -le $maxPage; $currentPage++) {
            #Write-Progress -Activity "Getting market orders" -Status "$currentPage/$maxPage gotten:" -PercentComplete ([float]$currentPage/[float]$maxPage)
            Invoke-WebRequest2 -Uri "${Uri}?page=$currentPage" -IgnorePages
        }
    }
}

