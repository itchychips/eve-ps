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
    [switch]$ProfitCalc,
    [parameter()]
    [int]$TaxSkill=0,
    [parameter()]
    [float]$CargoCapacity=3000
)

function Invoke-ProfitCalc {
    [CmdletBinding()]
    Param(
        [parameter()]
        [int]$TaxSkill=0,
        [parameter()]
        [float]$CargoCapacity=3000
    )

    while ($true) {
        $taxRate = 0.08*(1-0.11*$TaxSkill)
        $line = Read-Host -Prompt "command & price (tax skill: $TaxSkill)"
        if ($line -eq "q") {
            Write-Host "User quit"
            return
        }
        $split = $line -split " "
        $command = $split[0]
        $arguments = $split[1..$split.Count]
        if ($command -eq "b") {
            if ($arguments.Count -gt 1) {
                Write-Warning "All arguments beyond the first are ignored for this command."
            }
            # currently a string; need to convert
            $arguments[0] = [decimal]$arguments[0]
            # Tax is 0.08; broker fee is 0.0148
            [decimal]$breakEvenImmediate = $arguments[0] / (1 - $taxRate)
            [decimal]$breakEvenNonImmediate = $arguments[0] / (1 - ($taxRate + 0.0148))
            $formatted = "{0:n3} / {1:n3}" -f $breakEvenImmediate,$breakEvenNonImmediate
            Write-Host "Sell higher than (immediate/non-immediate): $formatted"
        }
        elseif ($command -eq "s") {
            if ($arguments.Count -gt 1) {
                Write-Warning "All arguments beyond the first are ignored for this command."
            }
            # currently a string; need to convert
            $arguments[0] = [decimal]$arguments[0]
            # Tax is 0.08; broker fee is 0.0148
            [decimal]$breakEvenImmediate = $arguments[0] * (1 - ($taxRate))
            [decimal]$breakEvenNonImmediate = $arguments[0] * (1 - ($taxRate + 0.0148))
            $formatted = "{0:n3} / {1:n3}" -f $breakEvenImmediate,$breakEvenNonImmediate
            Write-Host "Buy lower than (immediate/non-immediate): $formatted"
        }
        elseif ($command -eq "t") {
            if ($arguments.Count -gt 1) {
                Write-Warning "All arguments beyond the first are ignored for this command."
            }
            $TaxSkill = $arguments[0]
            $taxRate = 0.08*(1-0.11*$TaxSkill)
            Write-Host "Set tax rate to $taxRate"
        }
        elseif ($command -eq "c") {
            if ($arguments.Count -gt 1) {
                Write-Warning "All arguments beyond the first are ignored for this command."
            }
            $CargoCapacity = [float]$arguments[0]
            Write-Host "Set cargo capacity to $CargoCapacity."
        }
        elseif ($command -eq "bsc") {
            if ($arguments.Count -notin @(3,4)) {
                Write-Warning "Buy-sell-cargo needs 3 or arguments."
                continue
            }
            [float]$taxRate = 0.08*(1-0.11*$TaxSkill)

            $buyAt = [float]$arguments[0]
            $sellAt = [float]$arguments[1]
            $cargoPerUnit = [float]$arguments[2]
            $overrideMaxItems = [int]$arguments[3]

            if ($overrideMaxItems) {
                $maxItems = $CargoCapacity / $cargoPerUnit
                if ($maxItems -gt $overrideMaxItems) {
                    $maxItems = $overrideMaxItems
                }
                $overrideMaxItems = $null
            }
            else {
                $maxItems = $CargoCapacity / $cargoPerUnit
            }
            $breakEvenSell = $buyAt / (1 - ($taxRate))
            $profitPerUnit = $sellAt*(1 - $taxRate) - $breakEvenSell
            $profitPerM3 = $profitPerUnit / $cargoPerUnit
            $totalProfit = $profitPerUnit * $maxItems
            $formatted = "Total profit: {0:n3} ; Profit per cubic meter: {1:n3} ; Profit per unit: {2:n3} ; Total items: {3:n3}" -f $totalProfit,$profitPerM3,$profitPerUnit,$maxItems
            Write-Host $formatted
        }
        else {
            Write-Warning "Unknown command: $command (try 'b' or 's')"
        }
    }
}

if ($ProfitCalc) {
    Invoke-ProfitCalc -TaxSkill $TaxSkill -CargoCapacity $CargoCapacity
}
