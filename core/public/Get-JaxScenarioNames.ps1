function Get-JaxScenarioNames {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $FlowConfig
    )

    if (-not $FlowConfig.Contains('suite')) {
        return @()
    }

    $suite = $FlowConfig['suite']
    if ($null -eq $suite -or -not ($suite -is [System.Collections.IDictionary])) {
        return @()
    }

    if (-not $suite.Contains('scenarios')) {
        return @()
    }

    $scenarios = $suite['scenarios']
    if ($null -eq $scenarios -or -not ($scenarios -is [System.Collections.IDictionary])) {
        return @()
    }

    return @($scenarios.Keys | Sort-Object)
}
