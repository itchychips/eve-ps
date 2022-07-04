[CmdletBinding()]
Param(
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$EsiBaseUri = "https://esi.evetech.net/latest"

$global:LastHeaders = @{}
# Cache using: $Cache[$Uri] = $Expiry
$global:CacheExpiry = @{}
# Cache using: $Cache[$Uri] = $Etag
$global:CacheETag = @{}
# Cache using: $Cache[$Uri] = $Response
$global:CacheResponse = @{}

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
        [switch]$IgnorePages
        #[parameter(ParameterSetName="JsonBody")]
        #[string]$JsonBody
    )

    $now = Get-Date
    if ($CacheExpiry[$Uri] -and ($now -lt $CacheExpiry[$Uri])) {
        Write-Verbose "Currently before expiry.  Returning cached response."
        $result = $CacheResponse[$Uri].Content | ConvertFrom-Json | Convert-PSObjectProperty
    }

    $headers = @{
            "Accept-Language"="en"
            "Content-Type"="application/json"
            "Accept"="application/json"
        }

    # This is a bit hard to use, but would be good to use it later if we
    # industrialize this.
    if ($CacheETag[$Uri]) {
        $headers["If-None-Match"] = $CacheETag[$Uri]
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
        $global:LastHeaders = $result.Headers
    }
    catch {
        # For some reason they decided that 304 was an exceptional status...
        # Wonderful.  Spoiler: It's not, and throwing an exception here is
        # incredibly ridiculous.
        if ($_.Exception.Response.StatusCode -ne "NotModified") {
            throw
        }
        Write-Verbose "Got 304 status.  Using cached response."
        $result = $CacheResponse[$Uri]
        $global:LastHeaders = $_.Exception.Response.Headers
    }


    if ($result.Headers["ETag"]) {
        $global:CacheETag[$Uri] = $result.Headers["ETag"]
    }
    $global:CacheExpiry[$Uri] = $result.Headers["Expires"]
    $global:CacheResponse[$Uri] = $result

    $output = $result.Content | ConvertFrom-Json
    if ($output.GetType().BaseType.Name -ne "Array") {
        $output | Convert-PSObjectProperty
    }
    else {
        $output
    }

    if ($result.Headers["X-Pages"] -and -not $IgnorePages) {
        Write-Verbose "X-Pages header present.  Getting everything."
        $currentPage = 2
        [int]$maxPage = $result.Headers["X-Pages"]
        for ($currentPage = 2; $currentPage -le $maxPage; $currentPage++) {
            Write-Progress -Activity "Getting market orders" -Status "$currentPage/$maxPage Gotten:" -PercentComplete ([float]$currentPage/[float]$maxPage)
            Invoke-WebRequest2 -Uri "${Uri}?page=$currentPage" -IgnorePages
        }
    }
}

function Search-EsiId {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory)]
        [string[]]$SubString
    )

    Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/ids?datasource=tranquility&language=en" -Method Post -ArrayBody $SubString
}

function Get-EsiJitaReachable {
    [CmdletBinding()]
    Param(
        [parameter()]
        [switch]$IncludeLowSec,
        [parameter()]
        [switch]$IncludeNullSec
    )
}

# Lonetrek, The Forge, The Citadel, Metropolis
#
#

function Get-EsiSystem {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory)]
        [string]$Name
    )

    $result = Search-EsiId $Name
    foreach ($systemId in $result.Systems.id) {
        Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/systems/$($systemId)/"
    }
}

function Get-EsiConstellation {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [int]$ConstellationId
    )

    Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/constellations/$ConstellationId/"
}

function Get-EsiRegion {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [int]$RegionId
    )

    Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/regions/$RegionId/"
}

function Get-EsiMarketOrder {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName="RegionId")]
        [int]$RegionId,
        [parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName="SystemName")]
        [string]$SystemName,
        [parameter(ValueFromPipelineByPropertyName)]
        [int]$ItemId
    )

    if ($SystemName) {
        $RegionId = Get-EsiSystem $SystemName | Get-EsiConstellation | Get-EsiRegion | Select-Object -Expand RegionId
    }

    $queryParameter = ""
    if ($ItemId) {
        $queryParameter = "?type_id=$ItemId"
    }

    Invoke-WebRequest2 -Uri "$EsiBaseUri/markets/$RegionId/orders/$queryParameter"
}

function Search-EsiItem {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory)]
        [string]$Name
    )

    Invoke-WebRequest2 -Uri "$EsiBaseUri/search/?categories=inventory_type&search=$Name" | Select-Object @{"Name"="ItemId"; "Expression"={$_.InventoryType}}
}

function Get-EsiGroup {
    [CmdletBinding()]
    Param(
        [parameter()]
        [string]$Name
    )

    Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/groups/"
}

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

#function Get-MarketOrder {
#    [CmdletBinding()]
#    Param(
#        [parameter(Mandatory)]
#        [string]$
#    )
#}

#function Get-EsiSystemId {
#    [CmdletBinding()]
#    Param(
#    )
#
#    Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/systems"
#}

# This works so far...
#Import-Module PSSQLite
#
#$dataSource = "$pwd\sqlite-latest.sqlite"
#$typeIds = Invoke-SqliteQuery -DataSource $dataSource -Query "
#    -- Get salvaged materials IDs
#    SELECT it.typeID
#    FROM invTypes it
#        JOIN invGroups ig
#        ON ig.groupID = it.groupID
#        JOIN invCategories ic
#        ON ic.categoryID = ig.categoryID
#        JOIN invMarketGroups img
#        ON img.marketGroupID = it.marketGroupID
#    WHERE 1=1
#        AND img.marketGroupName = 'Salvaged Materials'
#    ORDER BY it.typeID;"
#
#$tradeHubs = Invoke-SqliteQuery -DataSource $dataSource -Query "
#    SELECT regionID, solarSystemID, solarSystemName
#    FROM mapSolarSystems mss
#    WHERE solarSystemName IN ('Jita', 'Amarr', 'Rens', 'Dodixie', 'Hek');"

# Testing marketstat API; really doesn't have a lot of information.
#$apiResult = Invoke-WebRequest -UseBasicParsing "https://api.evemarketer.com/ec/marketstat/json?typeid=25595"

#curl -X POST "https://esi.evetech.net/latest/universe/ids/?datasource=tranquility&language=en" -H  "accept: application/json" -H  "Accept-Language: en" -H  "Content-Type: application/json" -H  "Cache-Control: no-cache" -d "[  \"Jita\", \"Amarr\", \"Rens\", \"Dodixie\", \"Hek\"]"

$tradeHubSearchResult = Search-EsiId "Jita","Amarr","Rens","Dodixie","Hek"
$tradeHubs = $tradeHubSearchResult.systems

$alloyedExample = Search-EsiItem "Alloyed Tritanium Bar" | Get-EsiMarketOrder -SystemName Jita

# TODO: Get all Salvaged Materials items, loop over them, and pull all market orders in all regions.

#curl -X GET "https://esi.evetech.net/latest/universe/categories/?datasource=tranquility" -H  "accept: application/json" -H  "Cache-Control: no-cache"
