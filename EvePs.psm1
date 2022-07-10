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

Import-Module .\EsiWeb.psm1
Import-Module .\EvePsData.psm1
Import-Module .\EvePsUtil.psm1

$ErrorActionPreference = "Stop"

if (-not (Test-Path "$PSScriptRoot\secrets.ps1")) {
    throw "Please create secrets.ps1"
}

function Start-OAuthListener {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory)]
        [string]$Prefix
    )

    Write-Verbose "Starting HTTP listener for '$esiRedirectUri'."
    $httpListener = New-Object System.Net.HttpListener
    $httpListener.Prefixes.Add("$Prefix")
    $httpListener.Start()
    $httpListener
}

function Receive-OAuthResponse {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory,ValueFromPipeline)]
        [System.Net.HttpListener]$Listener,
        [parameter(Mandatory)]
        [string]$State
    )

    Write-Verbose "Waiting for a response"
    try {
        $context = $Listener.GetContext()
        Add-Type -AssemblyName System.Web
        $queryParameters = [System.Web.HttpUtility]::ParseQueryString($context.Request.Url.Query)
        $callbackState = $queryParameters.Get("state")
        if ($State -ne $callbackState) {
            $message = "Callback state was not expected state!  State received: '$callbackState'.  Expected: '$State'."
            $body = [System.Text.Encoding]::UTF8.GetBytes("ERROR: $message")
            $context.Response.StatusCode = 400
            $context.Response.ContentType = "text/plain"
            $context.Response.OutputStream.Write($body, 0, $body.Length)
            $context.Response.OutputStream.Close()
            throw "Callback state was not expected state!  State received: '$callbackState'.  Expected: '$State'."
        }
        $code = $queryParameters.Get("code")

        $message = "You are now logged into EVE-PS."
        $body = [System.Text.Encoding]::UTF8.GetBytes($message)
        $context.Response.StatusCode = 200
        $context.Response.ContentType = "text/plain"
        $context.Response.OutputStream.Write($body, 0, $body.Length)
        $context.Response.OutputStream.Close()

        $Listener.Stop()
        $Listener.Close()
        $Listener.Dispose()
        $Listener = $null

        $code
    }
    catch {
        $Listener.Stop()
        $Listener.Close()
        $Listener.Dispose()
        $Listener = $null
        throw
    }
    finally {
        if ($Listener) {
            $Listener.Stop()
            $Listener.Close()
            $Listener.Dispose()
        }
    }
}

function Invoke-EsiLogin {
    [CmdletBinding()]
    Param(
    )

    # Steps to this:
    #
    #   1. Craft the login URL
    #   2. Start a listener for an HTTP request.
    #   3. Open the login URL for the user.
    #   4. Wait for a response to the callback URL.
    #   5. Parse the callback URL response
    #       a. If the state is not the same, reject the login, send an error response, and end these steps.
    #       b. Save the code from the callback URL.
    #   6. Send a response to the callback URL indicating success.
    #   7. Use the code from the callback to get an OAUTH token.
    #   8. Use the OAUTH token to do everything against the ESI API.

    $esiCodeChallenge = Get-ChallengeCode
    $esiState = (New-Guid).Guid
    $eveLoginUrl = "https://login.eveonline.com/v2/oauth/authorize/"
    $esiRedirectUri = "http://localhost:64782/"
    # This should be space-separated.
    $scopes = "esi-universe.read_structures.v1"

    $eveLoginUrl += "?response_type=code"

    $eveLoginUrl += "&redirect_uri=$($esiRedirectUri | ConvertTo-UrlEncodedString)"
    $eveLoginUrl += "&client_id=$($global:EsiClientId | ConvertTo-UrlEncodedString)"
    $eveLoginUrl += "&scope=$($scopes | ConvertTo-UrlEncodedString)"
    $eveLoginUrl += "&code_challenge=$($esiCodeChallenge.Challenge)"
    $eveLoginUrl += "&code_challenge_method=$("S256" | ConvertTo-UrlEncodedString)"
    $eveLoginUrl += "&state=$($esiState | ConvertTo-UrlEncodedString)"

    $esiRedirectUri = "http://localhost:64782/"
    try {
        $listener = Start-OAuthListener -Prefix $esiRedirectUri

        Write-Verbose "Launching browser for '$eveLoginUrl'."
        Start-Process $eveLoginUrl

        $code = $listener | Receive-OAuthResponse -State $esiState
        # Listener is diposed in the Receive-OAuthResponse call.
        $listener = $null
        Write-Verbose "Got code!"
    }
    catch {
        if ($listener.IsListening) {
            $listener.Stop()
            $listener.Close()
        }
        $listener.Dispose()
        $listener = $null
        throw
    }
    finally {
        if ($listener) {
            $listener.Stop()
            $listener.Close()
            $listener.Dispose()
            $listener = $null
        }
    }

    $eveTokenUrl = "https://login.eveonline.com/v2/oauth/token/"
    #$eveTokenUrl += "?grant_type=authorization_code"
    #$eveTokenUrl += "&code=$($code | ConvertTo-UrlEncodedString)"
    #$eveTokenUrl += "&client_id=$($esiClientId | ConvertTo-UrlEncodedString)"
    #$eveTokenUrl += "&code_verifier=$($esiCodeChallenge.Verifier | ConvertTo-UrlEncodedString)"

    $body = @{
        "grant_type"="authorization_code"
        "code"="$code"
        "client_id"="$esiClientId"
        "code_verifier"="$($esiCodeChallenge.Verifier)"
    }

    $headers = @{
        "Content-Type"="application/x-www-form-urlencoded"
        "Host"="login.eveonline.com"
    }

    Write-Verbose "Sending OAuth token request using url '$eveTokenUrl'."
    $response = Invoke-WebRequest -UseBasicParsing -Uri $eveTokenUrl -Headers $headers -Method Post -Body $body
    Write-Verbose "Got response!"
    $response = $response | ConvertFrom-Json
    if (-not (Test-Variable -Name Authentication -Scope Global)) {
        $global:Authentication = New-Object -Type PSObject
        $global:Authentication | Add-Member -Type NoteProperty -Name AccessToken -Value $null
        $global:Authentication | Add-Member -Type NoteProperty -Name ExpiresAt -Value $null
        $global:Authentication | Add-Member -Type NoteProperty -Name TokenType -Value $null
        $global:Authentication | Add-Member -Type NoteProperty -Name RefreshToken -Value $null
    }
    $global:Authentication.AccessToken = $response.access_token
    $global:Authentication.ExpiresAt = (Get-Date) + (New-TimeSpan -Seconds $response.expires_in)
    $global:Authentication.TokenType = $response.token_type
    $global:Authentication.RefreshToken = $response.refresh_token
}

function Invoke-EsiLogout {
    [CmdletBinding()]
    Param(
    )

    if (Test-Variable -Name Authentication -Scope Global) {
        Remove-Variable -Name Authentication -Scope Global
    }
}

Import-Module PSSQLite

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

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
        [parameter(Mandatory,ParameterSetName="SystemName")]
        [string]$Name,
        [parameter(Mandatory,ParameterSetName="SystemId")]
        [long]$SystemId
    )

    if ($SystemId) {
        Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/systems/$($systemId)/"
        return
    }

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

#function Add-EsiGroup {
#    [CmdletBinding()]
#    Param(
#        [parameter(Mandatory)]
#        [Object]$SqliteConnection,
#        [parameter(ValueFromPipelineByPropertyName)]
#        [int]$CategoryId,
#        [parameter(ValueFromPipelineByPropertyName)]
#        [int]$GroupId,
#        [parameter(ValueFromPipelineByPropertyName)]
#        [string]$Name,
#        [parameter(ValueFromPipelineByPropertyName)]
#        [bool]$Published
#    )
#
#    Invoke-SqliteQuery -SQLiteConnection $SqliteConnection -Query "
#        INSERT INTO [group] (
#            CategoryId,
#            GroupId,
#            Name,
#            Published
#        ) VALUES (
#            @CategoryId,
#            @GroupId,
#            @Name,
#            @Published);" -SqlParameters @{
#                "CategoryId"=$CategoryId
#                "GroupId"=$GroupId
#                "Name"=$Name
#                "Published"=$Published
#            }
#}

function Sync-EsiGroup {
    [CmdletBinding()]
    Param(
        [parameter()]
        [switch]$Clobber
        # Useful for debugging PoshRSJob
        #[parameter()]
        #[int]$Limit
    )
    $connection = Open-EvePsDataConnection

    try {
        $transaction = $connection.BeginTransaction()
        $global:EvePsSqliteTransactions += $transaction

        if ($Clobber) {
            Invoke-SqliteQuery -SqliteConnection $connection -Query "
                DROP TABLE IF EXISTS [group];"
        }

        Invoke-SqliteQuery -SqliteConnection $connection -Query "
            CREATE TABLE IF NOT EXISTS [group] (
                CategoryId INTEGER,
                GroupId INTEGER PRIMARY KEY,
                Name STRING,
                Published INTEGER);
                "

        $groupIds = Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/groups/"
        $evePsModulePath = Get-Module EvePs | Select-Object -Expand Path

        #if ($Limit) {
        #    $groupIds = $groupIds | Select-Object -First $Limit
        #}

        $baseUri = $global:EsiBaseUri
        $groupIds | Start-RSJob -Throttle 100 -ModulesToImport $evePsModulePath -ScriptBlock {
            $global:EvePsSqliteConnection = $using:connection
            $group = Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/groups/$_/"
            Invoke-SqliteQuery -SQLiteConnection $using:connection -Query "
                INSERT OR REPLACE INTO [group] (
                    CategoryId,
                    GroupId,
                    Name,
                    Published
                ) VALUES (
                    @CategoryId,
                    (SELECT GroupId FROM [group] WHERE GroupId = @GroupId),
                    @Name,
                    @Published);" -SqlParameters @{
                        "CategoryId"=$group.CategoryId
                        "GroupId"=$group.GroupId
                        "Name"=$group.Name
                        "Published"=$group.Published
                    }
        } | Wait-RSJob -ShowProgress | Receive-RSJob

        $transaction.Commit()
        $transaction = $null
    }
    catch {
        if ($transaction) {
            $transaction.Rollback()
            $transaction = $null
        }
        throw
    }
    finally {
        if ($transaction) {
            $transaction.Rollback()
        }
    }
}

function Get-EsiGroup {
    [CmdletBinding()]
    Param(
        [parameter()]
        [string]$Name="*",
        [parameter()]
        [switch]$SerialExecution,
        [parameter()]
        [int]$Limit
    )

    Process {
        $now = Get-Date
        $groupIds = Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/groups/"
        if ($Limit) {
            $groupIds = $groupIds | Select-Object -First $Limit
        }

        if ($SerialExecution) {
            $groupIds | ForEach-Object {
                Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/groups/$_/" -Verbose
            } | Wait-RSJob -ShowProgress | Receive-RSJob | Where-Object { $_.Name -like $Name }
        }
        else {
            $evePsModulePath = Get-Module EvePs | Select-Object -Expand Path
            $sqliteConnection = $global:EvePsSqliteConnection
            $groupIds | Start-RSJob -Throttle 1 -ModulesToImport $evePsModulePath -ScriptBlock {
                $global:EvePsSqliteConnection = $using:EvePsSqliteConnection
                Invoke-WebRequest2 -Uri "$using:EsiBaseUri/universe/groups/$_/" -Verbose
            } | Wait-RSJob -ShowProgress | Receive-RSJob | Where-Object { $_.Name -like $Name }
        }
    }
}

function Get-EsiType {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipelineByPropertyName,ValueFromPipeline)]
        [int[]]$Types,
        [parameter()]
        [string]$Name="*",
        [parameter()]
        [int]$Count
    )

    Begin {
        $progressCount = 0
    }

    Process {
        if (-not $Types) {
            $Types = Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/types/"
        }
        $Types | ForEach-Object {
            Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/types/$_/"
            if ($Count) {
                Write-Progress -Activity "Getting EsiType" -Status "Got $progressCount/$Count" -PercentComplete ($progressCount / $Count)
            }
            $progressCount++
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
            #
            # Note: We need to cast all longs so they're detected properly.  If
            # we don't do this, then PSSqlite's Out-DataTable cmdlet could
            # throw an error (they call this out as a potential improvement,
            # but we could also just enforce the int64s).
            $output = New-Object -Type PSObject
            $output | Add-Member -Type NoteProperty -Name Duration -Value $_.duration
            $output | Add-Member -Type NoteProperty -Name "IsBuyOrder" -Value $_.is_buy_order
            $output | Add-Member -Type NoteProperty -Name "Issued" -Value $_.issued
            $output | Add-Member -Type NoteProperty -Name "LocationId" -Value ([long]($_.location_id))
            $output | Add-Member -Type NoteProperty -Name "MinVolume" -Value $_.min_volume
            $output | Add-Member -Type NoteProperty -Name "OrderId" -Value ([long]($_.order_id))
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
        $groups = Get-EsiGroup -Name $GroupName
        $typeIds = $groups | Get-EsiType -Count $groups.Count | Select-Object -Expand TypeId
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

function New-EsiSavedMarketOrderTable {
    [CmdletBinding()]
    Param(
        [parameter()]
        [switch]$Clobber
    )
    if ($Clobber) {
        Invoke-SqliteQuery -SqliteConnection $global:EvePsSqliteConnection -Query "
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
    Invoke-SqliteQuery -SqliteConnection $global:EvePsSqliteConnection -Query "
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
        [int]$VolumeTotal
    )
    Begin {
        New-EsiSavedMarketOrderTable
    }

    Process {
        Invoke-SqliteQuery -SqliteConnection $global:EvePsSqliteConnection -Query "
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

function New-EsiMarketOrderRelation {
    [CmdletBinding()]
    Param(
        [parameter()]
        [switch]$Clobber
    )

    if ($Clobber) {
        Invoke-SqliteQuery -SqliteConnection $global:EvePsSqliteConnection -Query "
            DROP TABLE IF EXISTS station;
            DROP TABLE IF EXISTS system;
            DROP TABLE IF EXISTS constellation;
            DROP TABLE IF EXISTS region;
            "
    }

    Invoke-SqliteQuery -SqliteConnection $global:EvePsSqliteConnection -Query "
        CREATE TABLE IF NOT EXISTS station (
            MaxDockableShipVolume DECIMAL,
            Name STRING,
            OfficeRentalCost DECIMAL,
            Owner INTEGER,
            RaceId INTEGER,
            ReprocessingEfficiency DECIMAL,
            ReprocessingStationsTake DECIMAL,
            StationId INTEGER PRIMARY KEY,
            SystemId INTEGER,
            TypeId INTEGER
        );

        CREATE TABLE IF NOT EXISTS system (
            ConstellationId INTEGER,
            Name STRING,
            SecurityClass STRING,
            SecurityStatus DECIMAL,
            StarId INTEGER,
            SystemId INTEGER PRIMARY KEY
        );

        CREATE TABLE IF NOT EXISTS constellation (
            ConstellationId INTEGER PRIMARY KEY,
            Name STRING,
            RegionId INTEGER
        );

        CREATE TABLE IF NOT EXISTS region (
            description STRING,
            Name STRING,
            RegionId INTEGER PRIMARY KEY
        );"
}

function Sync-EsiMarketOrderRelation {
    [CmdletBinding()]
    Param(
    )

    $stationIds = Invoke-SqliteQuery -SqliteConnection $global:EvePsSqliteConnection -Query "
        SELECT DISTINCT LocationId FROM market_order;" | Select-Object -Expand LocationId
    foreach ($stationId in $stationIds) {
        $station = Get-EsiStation -StationId $stationId
        $dataTable = $station | Select-Object MaxDockableShipVolume,Name,OfficeRentalCost,Owner,RaceId,ReprocessingEfficiency,ReprocessingStationsTake,StationId,SystemId,TypeId | Out-DataTable
        Invoke-SqliteBulkCopy -DataTable $dataTable -SqliteConnection $global:EvePsSqliteConnection -Table "station" -Confirm
    }
        #$constellationId = $system.ConstellationId
        #$constellation = Get-EsiConstellation -ConstellationId $constellationId
        #$region = Get-EsiRegion -RegionId $constellation.RegionId
}

function Get-EsiStation {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory)]
        [int]$StationId
    )
    Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/stations/$StationId/"
}

function Search-EsiMarketGap {
    [CmdletBinding()]
    Param(
        [parameter()]
        [decimal]$Tax=0.08,
        [parameter()]
        [string]$BuyFrom="*"
    )

    $typeNames = Invoke-SqliteQuery -SqliteConnection $global:EvePsSqliteConnection -Query "
        SELECT DISTINCT mo.TypeName
        FROM market_order mo
        ORDER BY mo.TypeName;" | Select-Object -Expand TypeName

    foreach ($typeName in $typeNames) {
        $buyOrders = Invoke-SqliteQuery -SqliteConnection $global:EvePsSqliteConnection -Query "
            SELECT mo.TypeName, mo.Price, mo.VolumeRemain, mo.LocationId AS StationId
            FROM market_order mo
            WHERE mo.IsBuyOrder = 1
                AND mo.TypeName = @TypeName
            ORDER BY mo.Price DESC;" -SqlParameters @{"TypeName"=$typeName} | Select-Object *,@{
                "Name"="Station"
                "Expression"={
                    $station = Get-EsiStation -StationId $_.StationId
                    $system = Get-EsiSystem -SystemId $station.SystemId
                    $constellation = Get-EsiConstellation -ConstellationId $system.ConstellationId
                    $region = Get-EsiRegion -RegionId $constellation.RegionId

                    $constellation | Add-Member -Type NoteProperty -Name Region -Value $region
                    $system | Add-Member -Type NoteProperty -Name Constellation -Value $constellation
                    $station | Add-Member -Type NoteProperty -Name System -Value $system
                    $station
                }
            }
        $sellOrders = Invoke-SqliteQuery -SqliteConnection $global:EvePsSqliteConnection -Query "
            SELECT mo.TypeName, mo.Price, mo.VolumeRemain, mo.LocationId AS StationId
            FROM market_order mo
            WHERE mo.IsBuyOrder = 0
                AND mo.TypeName = @TypeName
            ORDER BY mo.Price ASC;" -SqlParameters @{"TypeName"=$typeName} | Select-Object *,@{
                "Name"="Station"
                "Expression"={
                    $station = Get-EsiStation -StationId $_.StationId
                    $system = Get-EsiSystem -SystemId $station.SystemId
                    $constellation = Get-EsiConstellation -ConstellationId $system.ConstellationId
                    $region = Get-EsiRegion -RegionId $constellation.RegionId

                    $constellation | Add-Member -Type NoteProperty -Name Region -Value $region
                    $system | Add-Member -Type NoteProperty -Name Constellation -Value $constellation
                    $station | Add-Member -Type NoteProperty -Name System -Value $system
                    $station
                }
            }
        if (-not $buyOrders) {
            continue
        }
        elseif (-not $sellOrders) {
            continue
        }
        $breakEvenSell = $sellOrders[0].Price / (1 - $tax)
        if ($breakEvenSell -ge $buyOrders[0].Price) {
            continue
        }
        $output = New-Object -Type PSObject
        $output | Add-Member -Type NoteProperty -Name "TypeName" -Value $typeName
        $output | Add-Member -Type NoteProperty -Name "BuyOrders" -Value $buyOrders
        $output | Add-Member -Type NoteProperty -Name "SellOrders" -Value $SellOrders
        $output
    }
}

function Invoke-Test {
    $allMarketOrders = New-EsiMarketOrderSearch -RegionName "The Forge" -GroupName "Salvaged Materials" | Get-EsiMarketOrder    
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
#$typeIds = Invoke-SqliteQuery -SqliteConnection $global:EvePsSqliteConnection -Query "
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
#$tradeHubs = Invoke-SqliteQuery -SqliteConnection $global:EvePsSqliteConnection -Query "
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
