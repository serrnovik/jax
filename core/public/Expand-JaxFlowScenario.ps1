function Expand-JaxFlowScenario {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $FlowConfig,
        [string] $Scenario
    )

    if ($FlowConfig.Keys -notcontains 'suite') {
        return @()
    }
    $suite = $FlowConfig['suite']
    if ($null -eq $suite -or ($suite.Keys -notcontains 'scenarios')) {
        return @()
    }

    $scenarios = $suite['scenarios']
    if ($null -eq $scenarios -or $scenarios.Keys.Count -eq 0) {
        return @()
    }

    if ([string]::IsNullOrWhiteSpace($Scenario)) {
        $Scenario = $scenarios.Keys | Select-Object -First 1
    }

    if (-not ($scenarios.Keys -contains $Scenario)) {
        return @()
    }

    $scenarioConfig = $scenarios[$Scenario]
    if ($scenarioConfig -is [System.Collections.IDictionary]) {
        return @($scenarioConfig.Keys)
    }
    if ($scenarioConfig -is [string]) {
        return @($scenarioConfig)
    }
    if ($scenarioConfig -is [System.Collections.IEnumerable]) {
        return @($scenarioConfig)
    }

    return @()
}
