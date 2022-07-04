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

Import-Module PSSQLite

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$EsiBaseUri = "https://esi.evetech.net/latest"

if (-not $CacheExpiry -or $ClearCache) {
    $global:LastHeaders = @{}
    # Cache using: $Cache[$Uri] = $Expiry
    $global:CacheExpiry = @{}
    # Cache using: $Cache[$Uri] = $Etag
    $global:CacheETag = @{}
    # Cache using: $Cache[$Uri] = $Response
    $global:CacheResponse = @{}
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
        [switch]$IgnorePages
        #[parameter(ParameterSetName="JsonBody")]
        #[string]$JsonBody
    )

    $result = $null

    $now = Get-Date
    if ($CacheExpiry[$Uri] -and ($now -lt $CacheExpiry[$Uri])) {
        Write-Verbose "Currently before expiry for '$Uri'.  Returning cached response."
        $result = $CacheResponse[$Uri]
    }

    if (-not $result) {
        $headers = @{
                "Accept-Language"="en"
                "Content-Type"="application/json"
                "Accept"="application/json"
            }

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
            Write-Verbose "Got 304 status for '$Uri'.  Using cached response."
            $result = $CacheResponse[$Uri]
            $global:LastHeaders = $_.Exception.Response.Headers
        }
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
        Write-Verbose "X-Pages header present for '$Uri'.  Getting everything."
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
        [parameter()]
        [string]$Name="*",
        [parameter()]
        [int[]]$RegionId
    )

    Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/regions/" | ForEach-Object {
        Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/regions/$_/"
    } | Where-Object {
        $_.Name -like $Name -and
        (-not $RegionId -or $RegionId -contains $_.RegionId)
    }
}

function Search-EsiItem {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory)]
        [string]$Name
    )

    Invoke-WebRequest2 -Uri "$EsiBaseUri/search/?categories=inventory_type&search=$Name" | Select-Object @{"Name"="ItemId"; "Expression"={$_.InventoryType}}
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

function Get-EsiCategory {
    [CmdletBinding()]
    Param(
        [parameter()]
        [string]$Name="*"
    )

    $categoryIds = Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/categories"
    $results = $categoryIds | ForEach-Object {
        Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/categories/$_/"
    } | Where-Object { $_.Name -like $Name }
    $results
}

function Get-EsiGroup {
    [CmdletBinding()]
    Param(
        [parameter()]
        [string]$Name="*"
    )

    Process {
        Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/groups/" | ForEach-Object {
            Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/groups/$_/"
        } | Where-Object { $_.Name -like $Name }
    }
}

function Get-EsiType {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipelineByPropertyName,ValueFromPipeline)]
        [int[]]$Types,
        [parameter()]
        [string]$Name="*"
    )

    Process {
        if (-not $Types) {
            $Types = Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/types/"
        }
        $Types | ForEach-Object {
            Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/types/$_/"
        }
    }
}

function Get-EsiMarketOrder {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [int]$RegionId,
        [parameter(ValueFromPipelineByPropertyName)]
        [int]$TypeId
    )

    Process {
        $queryParameter = ""
        if ($TypeId) {
            $queryParameter = "?type_id=$TypeId"
        }

        Invoke-WebRequest2 -Uri "$EsiBaseUri/markets/$RegionId/orders/$queryParameter" | ForEach-Object {
            $type = Get-EsiType -Types $_.type_id

            # Not sure why this wasn't converted using Convert-PSObjectProperty.
            $output = New-Object -Type PSObject
            $output | Add-Member -Type NoteProperty -Name Duration -Value $_.duration
            $output | Add-Member -Type NoteProperty -Name "IsBuyOrder" -Value $_.is_buy_order
            $output | Add-Member -Type NoteProperty -Name "Issued" -Value $_.issued
            $output | Add-Member -Type NoteProperty -Name "LocationId" -Value $_.location_id
            $output | Add-Member -Type NoteProperty -Name "MinVolume" -Value $_.min_volume
            $output | Add-Member -Type NoteProperty -Name "OrderId" -Value $_.order_id
            $output | Add-Member -Type NoteProperty -Name "Price" -Value $_.price
            if ($_.range -eq "station") {
                $_.range = 0
            }
            elseif ($_.range -eq "solarsystem") {
                $_.range = -1
            }
            elseif ($_.range -eq "region") {
                $_.range = -2
            }
            $output | Add-Member -Type NoteProperty -Name "Range" -Value $_.range
            $output | Add-Member -Type NoteProperty -Name "SystemId" -Value $_.system_id
            $output | Add-Member -Type NoteProperty -Name "TypeId" -Value $_.type_id
            $output | Add-Member -Type NoteProperty -Name "TypeName" -Value $type.Name
            $output | Add-Member -Type NoteProperty -Name "TypeVolume" -Value $type.Volume
            $output | Add-Member -Type NoteProperty -Name "VolumeRemain" -Value $_.volume_remain
            $output | Add-Member -Type NoteProperty -Name "VolumeTotal" -Value $_.volume_total
            $output
        }
    }
}

function New-EsiMarketOrderSearch {
    [CmdletBinding()]
    Param(
        [parameter()]
        [string]$RegionName="*",
        [parameter()]
        [string]$GroupName="*"
    )

    Process {
        $regionIds = Get-EsiRegion -Name $RegionName | Select-Object -Expand RegionId
        if (-not $regionIds) {
            throw "No region IDs found.  Searched with: '$RegionName'."
        }
        $typeIds = Get-EsiGroup -Name $GroupName | Get-EsiType | Select-Object -Expand TypeId
        if (-not $typeIds) {
            throw "No type IDs found.  Searched with group: '$GroupName'."
        }

        foreach ($regionId in $regionIds) {
            foreach ($typeId in $typeIds) {
                $output = New-Object -Type PSObject
                $output | Add-Member -Type NoteProperty -Name "RegionId" -Value $regionId
                $output | Add-Member -Type NoteProperty -Name "TypeId" -Value $typeId
                $output
            }
        }
    }
}

function Create-EsiSavedMarketOrderTable {
    [CmdletBinding()]
    Param(
        [parameter()]
        [string]$DataSource="saved.sqlite",
        [parameter()]
        [switch]$Clobber
    )
    $DataSource = Resolve-Path $DataSource
    if ($Clobber) {
    Invoke-SqliteQuery -DataSource $DataSource -Query "
        DROP TABLE IF EXISTS market_order;"
    }

    # Note: If you use only INT, it will wrap a long int big enough to a
    # negative.  Fun little weird bug.  Always use INTEGER.
    #
    # You can test this weird phenomenon by doing this command:
    #
    #     Invoke-SqliteQuery -DataSource ":MEMORY:" -Query "CREATE TABLE test (id INT, id2 INTEGER); INSERT INTO test (id, id2) VALUES (@id, @id); SELECT * FROM test;" -SqlParameters @{"id"=1029209158478}
    #
    # I still can't believe I got all the types right here without
    # documentation.
    Invoke-SqliteQuery -DataSource $DataSource -Query "
        CREATE TABLE IF NOT EXISTS market_order (
            OrderId INTEGER PRIMARY KEY,
            Duration INTEGER,
            IsBuyOrder INTEGER,
            Issued DATETIME,
            LocationId INTEGER,
            MinVolume INTEGER,
            Price DECIMAL,
            Range INTEGER,
            SystemId INTEGER,
            TypeId INTEGER,
            TypeName STRING,
            TypeVolume DECIMAL,
            VolumeRemain INTEGER,
            VolumeTotal INTEGER
        );"
}

function Save-EsiMarketOrder {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipelineByPropertyName)]
        [int]$Duration,
        [parameter(ValueFromPipelineByPropertyName)]
        [bool]$IsBuyOrder,
        [parameter(ValueFromPipelineByPropertyName)]
        [datetime]$Issued,
        [parameter(ValueFromPipelineByPropertyName)]
        [long]$LocationId,
        [parameter(ValueFromPipelineByPropertyName)]
        [int]$MinVolume,
        [parameter(ValueFromPipelineByPropertyName)]
        [long]$OrderId,
        [parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [decimal]$Price,
        [parameter(ValueFromPipelineByPropertyName)]
        [int]$Range,
        [parameter(ValueFromPipelineByPropertyName)]
        [int]$SystemId,
        [parameter(ValueFromPipelineByPropertyName)]
        [int]$TypeId,
        [parameter(ValueFromPipelineByPropertyName)]
        [string]$TypeName,
        [parameter(ValueFromPipelineByPropertyName)]
        [decimal]$TypeVolume,
        [parameter(ValueFromPipelineByPropertyName)]
        [int]$VolumeRemain,
        [parameter(ValueFromPipelineByPropertyName)]
        [int]$VolumeTotal,
        [parameter()]
        [string]$DataSource="saved.sqlite"
    )
    Begin {
        $DataSource = Resolve-Path $DataSource
        Create-EsiSavedMarketOrderTable -DataSource $DataSource
    }

    Process {
        Invoke-SqliteQuery -DataSource $DataSource -Query "
            INSERT OR REPLACE INTO market_order (
                OrderId,
                Duration,
                IsBuyOrder,
                Issued,
                LocationId,
                MinVolume,
                Price,
                Range,
                SystemId,
                TypeId,
                TypeName,
                TypeVolume,
                VolumeRemain,
                VolumeTotal
            ) VALUES (
                (SELECT OrderId FROM market_order WHERE OrderId = @OrderId),
                @Duration,
                @IsBuyOrder,
                @Issued,
                @LocationId,
                @MinVolume,
                @Price,
                @Range,
                @SystemId,
                @TypeId,
                @TypeName,
                @TypeVolume,
                @VolumeRemain,
                @VolumeTotal
            );" -SqlParameters @{
                "OrderId"=$OrderId
                "Duration"=$Duration
                "IsBuyOrder"=$IsBuyOrder
                "Issued"=$Issued
                "LocationId"=$LocationId
                "MinVolume"=$MinVolume
                "Price"=$Price
                "Range"=$Range
                "SystemId"=$SystemId
                "TypeId"=$TypeId
                "TypeName"=$TypeName
                "TypeVolume"=$TypeVolume
                "VolumeRemain"=$VolumeRemain
                "VolumeTotal"=$VolumeTotal
            }
    }
}

function Search-EsiMarketGaps {
    [CmdletBinding()]
    Param(
        [parameter()]
        [string]$DataSource="saved.sqlite"
    )

    try {
        Set-StrictMode -Off
        $DataSource = Resolve-Path $DataSource

        $typeNames = Invoke-SqliteQuery -DataSource $DataSource -Query "
            SELECT DISTINCT mo.TypeName
            FROM market_order mo
            ORDER BY mo.TypeName;" | Select-Object -Expand TypeName

        foreach ($typeName in $typeNames) {
            $buyOrders = Invoke-SqliteQuery -DataSource $DataSource -Query "
                SELECT mo.TypeName, mo.Price, mo.VolumeRemain
                FROM market_order mo
                WHERE mo.IsBuyOrder = 1
                    AND mo.TypeName = @TypeName
                ORDER BY mo.Price DESC;" -SqlParameters @{"TypeName"=$typeName}
            $sellOrders = Invoke-SqliteQuery -DataSource $DataSource -Query "
                SELECT mo.TypeName, mo.Price, mo.VolumeRemain
                FROM market_order mo
                WHERE mo.IsBuyOrder = 0
                    AND mo.TypeName = @TypeName
                ORDER BY mo.Price ASC;" -SqlParameters @{"TypeName"=$typeName}
            $output = New-Object -Type PSObject
            $output | Add-Member -Type NoteProperty -Name "TypeName" -Value $typeName
            $output | Add-Member -Type NoteProperty -Name "BuyOrders" -Value $buyOrders
            $output | Add-Member -Type NoteProperty -Name "SellOrders" -Value $SellOrders
            $output
        }
    }
    finally {
        Set-StrictMode -Version Latest
    }
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

# TODO: Get all Salvaged Materials items, loop over them, and pull all market orders in all regions.

#curl -X GET "https://esi.evetech.net/latest/universe/categories/?datasource=tranquility" -H  "accept: application/json" -H  "Cache-Control: no-cache"

# Some scratchy stuff
#$tradeHubSearchResult = Search-EsiId "Jita","Amarr","Rens","Dodixie","Hek"
#$tradeHubs = $tradeHubSearchResult.systems
#
#$alloyedExample = Search-EsiItem "Alloyed Tritanium Bar" | Get-EsiMarketOrder -SystemName Jita
