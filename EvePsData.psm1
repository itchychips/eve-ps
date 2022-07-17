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
)

Import-Module $PSScriptRoot\EvePsUtil.psm1

$ErrorActionPreference = "Stop"

# Preserve open connections in current session.
if (-not (Test-Variable -Name EvePsSqliteConnection -Scope Global)) {
    $global:EvePsSqliteConnection = $null
    $global:EvePsSqliteTransactions = @()
}
else {
    Write-Verbose "Open connection at `$global:EvePsSqliteConnection preserved."
}

function ConvertTo-DbValue {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipeline)]
        [Object]$InputObject
    )

    Process {
        if ($InputObject -eq $null) {
            [System.DBNull]::Value
        }
        else {
            $InputObject
        }
    }
}

function Open-EvePsDataConnection {
    [CmdletBinding()]
    Param(
        [parameter()]
        [string]$DataSource
    )

    if ($global:EvePsSqliteConnection) {
        #Write-Verbose "Sqlite connection already opened."
        return $global:EvePsSqliteConnection
    }

    if (-not $DataSource) {
        if (Test-Variable -Name EvePsDataSource -Scope Global) {
            $DataSource = $global:EvePsDataSource
            Write-Verbose "Using overridden data source path: '$DataSource' from `$global:EvePsDataSource."
        }
        else {
            $DataSource = "$pwd\saved.sqlite"
            Write-Verbose "Using default data source path: '$DataSource'.  Use `$global:EvePsDataSource to override default."
        }
    }
    $DataSource = Resolve-path $DataSource
    $global:EvePsSqliteConnection = New-SQLiteConnection -DataSource $DataSource
    Write-Verbose "Sqlite connection to '$DataSource' opened.  Use `$global:EvePsSqliteConnection to access."
    $global:EvePsSqliteConnection
}

function Close-EvePsDataConnection {
    [CmdletBinding()]
    Param(
    )

    if (-not $global:EvePsSqliteConnection) {
        Write-Verbose "No connection open."
        return
    }
    $global:EvePsSqliteConnection.Close()
    $global:EvePsSqliteConnection.Dispose()
    $global:EvePsSqliteConnection = $null
}

function Unregister-EsiGroup {
    [CmdletBinding()]
    Param(
    )

    $connection = Open-EvePsDataConnection

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        DROP TABLE IF EXISTS [group];"
}

function Register-EsiGroup {
    [CmdletBinding()]
    Param(
    )
    $connection = Open-EvePsDataConnection

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        CREATE TABLE IF NOT EXISTS [group] (
            GroupId INTEGER PRIMARY KEY,
            CategoryId INTEGER,
            Name STRING,
            Published INTEGER);"
}

function Add-EsiGroup {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[long]]$CategoryId,
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [long]$GroupId,
        [parameter(ValueFromPipelineByPropertyName)]
        [string]$Name,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[bool]]$Published
    )

    Process {
        $connection = Open-EvePsDataConnection

        Invoke-SqliteQuery -Connection $connection -Query "
            INSERT INTO [group] (
                CategoryId,
                GroupId,
                Name,
                Published
            ) VALUES (
                @CategoryId,
                @GroupId,
                @Name,
                @Published);" -SqlParameters @{
                    "CategoryId"=$CategoryId
                    "GroupId"=$GroupId
                    "Name"=$Name
                    "Published"=$Published
                }
    }
}

function Unregister-EsiType {
    [CmdletBinding()]
    Param(
    )
    $connection = Open-EvePsDataConnection

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        DROP TABLE IF EXISTS [type];"
}

function Reset-EsiGroup {
    [CmdletBinding()]
    Param(
    )

    $connection = Open-EvePsDataConnection

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        DELETE FROM [group]
        WHERE 1=1;"
}

function Update-EsiGroup {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipelineByPropertyName)]
        [long]$CategoryId,
        [parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [long]$GroupId,
        [parameter(ValueFromPipelineByPropertyName)]
        [string]$Name,
        [parameter(ValueFromPipelineByPropertyName)]
        [bool]$Published,
        [parameter(ValueFromPipelineByPropertyName)]
        [long[]]$Types
    )
    #ForEach-Object {
    #        $group = $_
    #        Invoke-SqliteQuery -SqliteConnection $connection -Query "
    #            UPDATE [group]
    #            SET CategoryId = @CategoryId,
    #                Name = @Name,
    #                Published = @Published
    #            WHERE GroupId = @GroupId;" -SqlParameters @{
    #                "GroupId"=$group.GroupId
    #                "CategoryId"=$group.CategoryId
    #                "Name"=$group.Name
    #                "Published"=$group.Published
    #            }
    #        $group.types | Add-EsiType
    #    }

    Process {
        $connection = Open-EvePsDataConnection
        Invoke-SqliteQuery -SqliteConnection $connection -Query "
            UPDATE [group]
            SET CategoryId = @CategoryId,
                Name = @Name,
                Published = @Published
            WHERE GroupId = @GroupId;" -SqlParameters @{
                "GroupId"=$GroupId
                "CategoryId"=$CategoryId
                "Name"=$Name
                "Published"=$Published
            }
        if ($Types) {
            $Types | Add-EsiType
        }
    }
}

function Sync-EsiGroup {
    [CmdletBinding()]
    Param(
    )
    $connection = Open-EvePsDataConnection
    $transaction = $connection.BeginTransaction()

    try {
        Unregister-EsiType
        Unregister-EsiGroup

        Sync-EsiCategory

        Register-EsiType

        $evePsModulePath = Get-Module EvePs | Select-Object -Expand Path
        # For some reason, -ModulesToImport doesn't work anymore.
        Get-EsiGroup | Start-RSJob -Throttle 100 {
            Import-Module $using:evePsModulePath
            $global:EvePsSqliteConnection = $using:connection
            Invoke-WebRequest2 -Uri "$using:EsiBaseUri/universe/groups/$($_.GroupId)/"
        } | Wait-RSJob -ShowProgress | Receive-RSJob | Update-EsiGroup
        $transaction.Commit()
        $count = Invoke-SqliteQuery -SqliteConnection $connection -Query "
            SELECT COUNT(*) AS Count
            FROM [group];" | Select-Object -Expand Count
        Write-Verbose "There are now $count group IDs in database."
        $count = Invoke-SqliteQuery -SqliteConnection $connection -Query "
            SELECT COUNT(*) AS Count
            FROM type;" | Select-Object -Expand Count
        Write-Verbose "There are now $count type IDs in database."
    }
    catch {
        $transaction.Dispose()
        throw
    }
}

function Unregister-EsiCategory {
    [CmdletBinding()]
    Param(
    )

    $connection = Open-EvePsDataConnection

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        DROP TABLE IF EXISTS category;"
}

function Register-EsiCategory {
    [CmdletBinding()]
    Param(
    )

    $connection = Open-EvePsDataConnection

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        CREATE TABLE IF NOT EXISTS category (
            CategoryId INTEGER PRIMARY KEY,
            Name STRING,
            Published INTEGER
        );"
}

function Add-EsiCategory {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [long]$CategoryId,
        [parameter(ValueFromPipelineByPropertyName)]
        [string]$Name,
        [parameter(ValueFromPipelineByPropertyName)]
        [bool]$Published,
        [parameter(ValueFromPipelineByPropertyName)]
        [Object[]]$Groups
    )

    Process {
        Invoke-SqliteQuery -Connection $connection -Query "
            INSERT INTO category (
                CategoryId,
                Name,
                Published
            ) VALUES (
                @CategoryId,
                @Name,
                @Published)
            ON CONFLICT (CategoryId) DO
            UPDATE SET
                Name=@Name,
                Published=@Published;" -SqlParameters @{
                    "CategoryId"=$CategoryId
                    "Name"=$Name
                    "Published"=$Published
                }

        $Groups | Add-EsiGroup
    }
}

function Sync-EsiCategory {
    [CmdletBinding()]
    Param(
    )
    
    $connection = Open-EvePsDataConnection
    $transaction = $connection.BeginTransaction()

    try {
        Unregister-EsiGroup
        Unregister-EsiCategory

        Register-EsiCategory
        Register-EsiGroup

        Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/categories/" | ForEach-Object {
                Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/categories/$($_)/"
            } | Add-EsiCategory

        Write-Verbose "Committing transaction."
        $transaction.Commit()
        $count = Invoke-SqliteQuery -SqliteConnection $connection -Query "
            SELECT COUNT(*) AS Count FROM category;" | Select-Object -Expand Count

        Write-Verbose "There are $count entries for categories."

        $count = Invoke-SqliteQuery -SqliteConnection $connection -Query "
            SELECT COUNT(*) AS Count FROM [group];" | Select-Object -Expand Count
        Write-Verbose "There are $count entries for groups."
    }
    catch {
        $transaction.Dispose()
        throw
    }
}

function Unregister-EsiMarketGroup {
    [CmdletBinding()]
    Param(
    )
    $connection = Open-EvePsDataConnection

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        DROP TABLE IF EXISTS market_group;"
}

function Register-EsiMarketGroup {
    [CmdletBinding()]
    Param(
    )
    $connection = Open-EvePsDataConnection

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        CREATE TABLE IF NOT EXISTS market_group (
            MarketGroupId INTEGER PRIMARY KEY,
            ParentGroupId INTEGER,
            Description STRING,
            Name STRING
        );"
}

function Reset-EsiType {
    [CmdletBinding()]
    Param(
    )
    
    $connection = Open-EvePsDataConnection

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        DELETE FROM type
        WHERE 1=1;"
}

function Register-EsiType {
    [CmdletBinding()]
    Param(
    )
    $connection = Open-EvePsDataConnection

    Invoke-SqliteQuery -SqliteConnection $connection -Query "
        CREATE TABLE IF NOT EXISTS type (
            TypeId INTEGER PRIMARY KEY,
            GroupId INTEGER,
            MarketGroupId INTEGER,
            Capacity FLOAT,
            Description STRING,
            Mass FLOAT,
            Name STRING,
            PackagedVolume DECIMAL,
            PortionSize INTEGER,
            Published INTEGER,
            Radius FLOAT,
            Volume DECIMAL);"
}

function Add-EsiType {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[float]]$Capacity,
        [parameter(ValueFromPipelineByPropertyName)]
        [string]$Description,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[long]]$GroupId,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[long]]$MarketGroupId,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[float]]$Mass,
        [parameter(ValueFromPipelineByPropertyName)]
        [string]$Name,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[float]]$PackagedVolume,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[long]]$PortionSize,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[bool]]$Published,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[float]]$Radius,
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [long]$TypeId,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[float]]$Volume
    )

    Process {
        $connection = Open-EvePsDataConnection

        Invoke-SqliteQuery -SqliteConnection $connection -Query "
            INSERT INTO type (
                Capacity,
                Description,
                GroupId,
                MarketGroupId,
                Mass,
                Name,
                PackagedVolume,
                PortionSize,
                Published,
                Radius,
                TypeId,
                Volume
            ) VALUES (
                @Capacity,
                @Description,
                @GroupId,
                @MarketGroupId,
                @Mass,
                @Name,
                @PackagedVolume,
                @PortionSize,
                @Published,
                @Radius,
                @TypeId,
                @Volume)
            ON CONFLICT (TypeId) DO
            UPDATE SET
                Capacity=@Capacity,
                Description=@Description,
                GroupId=@GroupId,
                MarketGroupId=@MarketGroupId,
                Mass=@Mass,
                Name=@Name,
                PackagedVolume=@PackagedVolume,
                PortionSize=@PortionSize,
                Published=@Published,
                Radius=@Radius,
                Volume=@Volume;" -SqlParameters @{
                    "Capacity"=$Capacity
                    "Description"=$Description
                    "GroupId"=$GroupId
                    "MarketGroupId"=$MarketGroupId
                    "Mass"=$Mass
                    "Name"=$Name
                    "PackagedVolume"=$PackagedVolume
                    "PortionSize"=$PortionSize
                    "Published"=$Published
                    "Radius"=$Radius
                    "TypeId"=$TypeId
                    "Volume"=$Volume
                }
    }
}

function Get-EsiType {
    [CmdletBinding()]
    Param(
        [parameter()]
        [string]$Name="*"
    )

    Process {
        $connection = Open-EvePsDataConnection
        Invoke-SqliteQuery -SqliteConnection $connection -Query "
            SELECT Capacity,
                Description,
                GroupId,
                MarketGroupId,
                Mass,
                Name,
                PackagedVolume,
                PortionSize,
                Published,
                Radius,
                TypeId,
                Volume
            FROM type;" | Where-Object { $_.Name -like $Name }
    }
}

function Update-EsiType {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[float]]$Capacity,
        [parameter(ValueFromPipelineByPropertyName)]
        [string]$Description,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[long]]$GroupId,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[long]]$MarketGroupId,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[float]]$Mass,
        [parameter(ValueFromPipelineByPropertyName)]
        [string]$Name,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[float]]$PackagedVolume,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[long]]$PortionSize,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[bool]]$Published,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[float]]$Radius,
        [parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [long]$TypeId,
        [parameter(ValueFromPipelineByPropertyName)]
        [Nullable[float]]$Volume
    )

    Process {
        $connection = Open-EvePsDataConnection
        Invoke-SqliteQuery -SqliteConnection $connection -Query "
            UPDATE type
            SET
                Capacity=@Capacity,
                Description=@Description,
                GroupId=@GroupId,
                MarketGroupId=@MarketGroupId,
                Mass=@Mass,
                Name=@Name,
                PackagedVolume=@PackagedVolume,
                PortionSize=@PortionSize,
                Published=@Published,
                Radius=@Radius,
                Volume=@Volume
            WHERE TypeId = @TypeId;" -SqlParameters @{
                    "Capacity"=$Capacity
                    "Description"=$Description
                    "GroupId"=$GroupId
                    "MarketGroupId"=$MarketGroupId
                    "Mass"=$Mass
                    "Name"=$Name
                    "PackagedVolume"=$PackagedVolume
                    "PortionSize"=$PortionSize
                    "Published"=$Published
                    "Radius"=$Radius
                    "TypeId"=$TypeId
                    "Volume"=$Volume
                }
    }
}

function Sync-EsiType {
    [CmdletBinding()]
    Param(
        [parameter()]
        [switch]$UseRsJob,
        [parameter()]
        [switch]$UseSingleThread,
        [parameter()]
        [switch]$UsePsJob
    )

    $method = "rsJob"
    if ($UseRsJob) {
        $method = "rsJob"
    }
    elseif ($UsePsJob) {
        $method = "psJob"
    }
    elseif ($UseSingleThread) {
        $method = "singleThread"
    }

    $connection = Open-EvePsDataConnection
    $transaction = $connection.BeginTransaction()

    try {
        #Unregister-EsiMarketGroup
        #Unregister-EsiType

        #Sync-EsiGroup

        Register-EsiMarketGroup

        #Get-EsiGroup | Start-RSJob -Throttle 100 {
        #Get-EsiGroup | Start-RSJob -Throttle 100 {
        #    Import-Module $using:evePsModulePath
        #    $global:EvePsSqliteConnection = $using:connection
        #    Invoke-WebRequest2 -Uri "$using:EsiBaseUri/universe/groups/$($_.GroupId)/"
        #} | Wait-RSJob -ShowProgress | Receive-RSJob | Update-EsiGroup

        $evePsModulePath = Get-Module EvePs | Select-Object -Expand Path
        if ($method -eq "rsJob") {
            Get-EsiType | Start-RSJob -Throttle 30 {
                Import-Module $using:evePsModulePath
                $global:EvePsSqliteConnection = $using:connection
                Invoke-WebRequest2 -Uri "$using:EsiBaseUri/universe/types/$($_.TypeId)/"
            } | Wait-RSJob -ShowProgress | Receive-RSJob | Update-EsiType
        }
        elseif ($method -eq "singleThread") {
            $typeIds = Get-EsiType
            $count = 0
            $maxCount = $typeIds.Count
            $typeIds | ForEach-Object {
                Write-Progress -Activity "Getting types" -Status "$count/$maxCount gotten:" -PercentComplete ($count/$maxCount)
                $count += 1
                Invoke-WebRequest2 -Uri "$EsiBaseUri/universe/types/$($_.TypeId)/"
            } | Update-EsiType
        }
        else {
            throw "Unknown `$method set: '$method'."
        }

        $transaction.Commit()
    }
    catch {
        $transaction.Dispose()
        throw
    }
    finally {
        # If ctrl+C is hit, this will still be open and lock the database from
        # future use.
        if ($transaction.Connection) {
            $transaction.Dispose()
        }
    }
}

