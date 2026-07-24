# TestHelpers.psm1
function Invoke-WithTimeout {
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        [int]$TimeoutSeconds = 5,
        [object[]] $ArgumentList = @(),
        [string] $VariablesModulePath = (Join-Path $PSScriptRoot '..' 'MustachePlaceholders.psm1')
    )

    $job = Start-Job -ArgumentList @($ScriptBlock, $ArgumentList, $VariablesModulePath) -ScriptBlock {
        param($sb, $argsList, $modulePath)

        if ($modulePath -and (Test-Path $modulePath)) {
            Import-Module $modulePath -DisableNameChecking -Force | Out-Null
        }

        if ($sb -is [string]) {
            $sb = [ScriptBlock]::Create($sb)
        }

        & $sb @argsList
    }

    if (Wait-Job $job -Timeout $TimeoutSeconds) {
        Receive-Job $job -ErrorAction Stop
    } else {
        Remove-Job $job -Force
        throw "Operation timed out after $TimeoutSeconds seconds"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Invoke-WithTimeout'
)
