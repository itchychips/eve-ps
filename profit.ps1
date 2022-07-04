[CmdletBinding()]
Param(
    [parameter()]
    [switch]$ProfitCalc
)

function Invoke-ProfitCalc {
    [CmdletBinding()]
    Param(
    )

    while ($true) {
        $line = Read-Host -Prompt "command & price"
        if ($line -eq "q") {
            Write-Host "User quit"
            return
        }
        $split = $line -split " "
        if ($split.Count -ne 2) {
            Write-Warning "Must have only 2 values, separated by space (e.g. 'b 5' or 's 6')."
            continue
        }
        $command = $split[0]
        $price = $split[1]
        if ($command -eq "b") {
            # currently a string; need to convert
            $price = [decimal]$price
            # Tax is 0.08; broker fee is 0.0148
            [decimal]$breakEvenImmediate = $price / (1 - (0.08))
            [decimal]$breakEvenNonImmediate = $price / (1 - (0.08 + 0.0148))
            $formatted = "{0:n3} / {1:n3}" -f $breakEvenImmediate,$breakEvenNonImmediate
            Write-Host "Sell higher than (immediate/non-immediate): $formatted"
        }
        elseif ($command -eq "s") {
            # currently a string; need to convert
            $price = [decimal]$price
            # Tax is 0.08; broker fee is 0.0148
            [decimal]$breakEvenImmediate = $price * (1 - (0.08))
            [decimal]$breakEvenNonImmediate = $price * (1 - (0.08 + 0.0148))
            $formatted = "{0:n3} / {1:n3}" -f $breakEvenImmediate,$breakEvenNonImmediate
            Write-Host "Buy lower than (immediate/non-immediate): $formatted"
        }
        else {
            Write-Warning "Unknown command: $command (try 'b' or 's')"
        }
    }
}

if ($ProfitCalc) {
    Invoke-ProfitCalc
}
