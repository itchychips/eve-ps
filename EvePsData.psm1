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

Import-Module .\EvePsUtil.psm1

# Preserve open connections in current session.
if (-not (Test-Variable -Name EvePsSqliteConnection -Scope Global)) {
    $global:EvePsSqliteConnection = $null
    $global:EvePsSqliteTransactions = @()
}
else {
    Write-Verbose "Open connection at `$global:EvePsSqliteConnection preserved."
}

function Open-EvePsDataConnection {
    [CmdletBinding()]
    Param(
        [parameter()]
        [string]$DataSource
    )

    if ($global:EvePsSqliteConnection) {
        Write-Verbose "Sqlite connection already opened."
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
