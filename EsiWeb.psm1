[CmdletBinding()]
Param(
    [parameter()]
    [switch]$ClearCache
)

$global:EsiBaseUri = "https://esi.evetech.net/latest"

$ErrorActionPreference = "Stop"

Set-StrictMode -Version Latest

[System.Net.ServicePointManager]::SecurityProtocol = "Tls12"

function Test-Member {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory)]
        [string]$MemberName,
        [parameter(Mandatory,ValueFromPipeline)]
        [Object]$InputObject
    )

    (Get-Member -InputObject $InputObject | Where-Object { $_.Name -eq $MemberName }) -ne $null
}

function Clear-Cache {
    [CmdletBinding()]
    Param(
        [parameter()]
        [string]$DataSource="saved.sqlite"
    )

    $DataSource = Resolve-Path $DataSource

    Invoke-SqliteQuery -DataSource $DataSource -Query "
        DROP TABLE IF EXISTS cache_web;
        DROP TABLE IF EXISTS cache_etag;

        CREATE TABLE IF NOT EXISTS cache_web (
            CacheWebId INTEGER PRIMARY KEY,
            Uri STRING,
            ETag STRING,
            Response STRING,
            Expiry DATETIME
        );"

    # Cache using: $Cache[$Uri] = $Expiry
    #$global:CacheExpiry = @{}
    ## Cache using: $Cache[$Uri] = $Etag
    #$global:CacheETag = @{}
    ## Cache using: $Cache[$Uri] = $Response
    #$global:CacheResponse = @{}
}

$global:LastHeaders = @{}

#if (-not (Test-Path variable:\CacheExpiry) -or $ClearCache) {
#    Clear-Cache
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
        [string]$DataSource="saved.sqlite",
        [parameter()]
        [switch]$IgnoreExpiry,
        [parameter()]
        [switch]$IgnoreETag
        #[parameter(ParameterSetName="JsonBody")]
        #[string]$JsonBody
    )

    $DataSource = Resolve-Path $DataSource

    $result = $null

    $now = Get-Date
    $cacheEntry = Invoke-SqliteQuery -DataSource $DataSource -Query "
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
            $result = Invoke-WebRequest @params
            $transformedResult = New-Object -Type PSObject
            $transformedResult | Add-Member -Type NoteProperty -Name "Headers" -Value $result.Headers
            $transformedResult | Add-Member -Type NoteProperty -Name "Content" -Value $result.Content
            $result = $transformedResult
            $global:LastHeaders = $result.Headers
        }
        catch {
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
        Invoke-SqliteQuery -DataSource $DataSource -Query "
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
        Invoke-SqliteQuery -DataSource $DataSource -Query "
            UPDATE cache_web
            SET ETag = @ETag
            WHERE Uri = @Uri;" -SqlParameters @{
                "ETag"=$result.Headers.ETag
                "Uri"=$Uri
            }
    }
    $response = New-Object -Type PSObject
    $response | Add-Member -Type NoteProperty -Name "Headers" -Value $result.Headers
    $response | Add-Member -Type NoteProperty -Name "Content" -Value $result.Content

    $expiry = Get-Date $result.Headers.Expires -Format o
    Invoke-SqliteQuery -DataSource $DataSource -Query "
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

    if (($result | Test-Member -MemberName "X-Pages") -and -not $IgnorePages) {
        Write-Verbose "X-Pages header present for '$Uri'.  Getting everything."
        $currentPage = 2
        [int]$maxPage = $result."X-Pages"
        for ($currentPage = 2; $currentPage -le $maxPage; $currentPage++) {
            Write-Progress -Activity "Getting market orders" -Status "$currentPage/$maxPage gotten:" -PercentComplete ([float]$currentPage/[float]$maxPage)
            Invoke-WebRequest2 -Uri "${Uri}?page=$currentPage" -IgnorePages
        }
    }
}

