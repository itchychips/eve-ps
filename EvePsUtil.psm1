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

function Test-Variable {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory)]
        [string]$Name,
        [parameter()]
        [string]$Scope="Local"
    )

    $variables = Get-Variable -Scope $Scope | Where-Object { $_.Name -eq $Name }
    if ($variables) {
        return $true
    }
    $false
}

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

function ConvertTo-UrlBase64String {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipeline)]
        [Object]$InputObject
    )

    Begin {
        $objects = @()
    }

    Process {
        $objects += $InputObject
    }

    End {
        [System.Convert]::ToBase64String($objects).TrimEnd("=").Replace("+","-").Replace("/","_")
    }

}

function ConvertTo-Sha256Sum {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipeline)]
        [Object]$InputObject
    )

    Begin {
        $objects = @()
    }

    Process {
        $objects += $InputObject
    }

    End {
        try {
            $hasher = [System.Security.Cryptography.SHA256]::Create()
            $hasher.ComputeHash($objects)
        }
        finally {
            $hasher.Dispose()
        }
    }

}

function ConvertFrom-Utf8String {
    [CmdletBinding()]
    Param(
        [parameter(ValueFromPipeline)]
        [Object]$InputObject
    )

    Begin {
        $objects = @()
    }
    
    Process {
        $objects += $InputObject
    }

    End {
        [System.Text.Encoding]::UTF8.GetBytes($objects)
    }
}

function Get-RandomByte {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory)]
        [int]$Count
    )

    1..$Count | ForEach-Object {
        [byte](Get-Random -Max 256)
    }
}

function ConvertTo-UrlEncodedString {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory,ValueFromPipeline)]
        [string]$InputObject
    )

    [uri]::EscapeDataString($InputObject)
}

function Get-ChallengeCode {
    [CmdletBinding()]
    Param(
    )

    $hasher = [System.Security.Cryptography.SHA256]::Create()

    #$characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    $output = New-Object -Type PSObject

    $challenge = Get-RandomByte -Count 32
    $challenge = $challenge | ConvertTo-UrlBase64String
    $output | Add-Member -Type NoteProperty -Name "Verifier" -Value $challenge
    Write-Debug "Verifier: $challenge"
    $challenge = $challenge | ConvertFrom-Utf8String
    $challenge = $challenge | ConvertTo-Sha256Sum
    $challenge = $challenge | ConvertTo-UrlBase64String
    $output | Add-Member -Type NoteProperty -Name "Challenge" -Value $challenge
    Write-Debug "Challenge: $challenge"
    $output
}

