function Get-JaxScenarioRunEntities {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $FlowConfig,
        [string] $Scenario,
        [string] $ProvenancePath,
        [hashtable] $Context = @{}
    )

    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    # Core defaults (repo-agnostic). IMPORTANT: do NOT auto-inject RepoRoot into Context here.
    # If RepoRoot is present, hooks/plugins may auto-load based on repo config. That is desired for CLI runs,
    # but it makes direct API calls (and unit tests) non-deterministic.
    $repoRootForOverrides = $null
    if ($Context.ContainsKey('RepoRoot') -and -not [string]::IsNullOrWhiteSpace([string]$Context['RepoRoot'])) {
        $repoRootForOverrides = [string]$Context['RepoRoot']
    } else {
        $repoRootForOverrides = Get-JaxRepoRoot
    }
    $coreOverride = @{
        env = @{
            git   = @{
                root = $repoRootForOverrides
            }
            build = @{
                counter = 0
            }
        }
    }
    $existingOverride = @{}
    if ($Context.ContainsKey('VariablesOverride') -and $Context['VariablesOverride'] -is [System.Collections.IDictionary]) {
        $existingOverride = $Context['VariablesOverride']
    }
    $Context['VariablesOverride'] = Merge-JaxHashtable -Base $coreOverride -Overlay $existingOverride

    Invoke-JaxHooks -Name 'BeforeSequenceResolve' -Context $Context -Data @{
        FlowConfig     = $FlowConfig
        Scenario       = $Scenario
        FlowConfigPath = $ProvenancePath
    }

    if ($Context.ContainsKey('RunConfig') -and $Context['RunConfig'] -is [System.Collections.IDictionary]) {
        $override = $Context['RunConfig']
        if ($Context.ContainsKey('VariablesOverride') -and $Context['VariablesOverride'] -is [System.Collections.IDictionary]) {
            $override = $Context['VariablesOverride']
        }
        $FlowConfig = Expand-JaxPlaceholders -Config $FlowConfig -Override $override -DontThrow
    }

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

    if ([string]::IsNullOrWhiteSpace($Scenario)) {
        if ($scenarios.Keys -contains 'default') {
            $Scenario = 'default'
        } else {
            $Scenario = $scenarios.Keys | Select-Object -First 1
        }
    }

    if (-not ($scenarios.Keys -contains $Scenario)) {
        return @()
    }

    $scenarioConfig = $scenarios[$Scenario]
    $entities = @()

    if ($scenarioConfig -is [System.Collections.IDictionary]) {
        # Expose raw scenario item definitions for resolvers (e.g. bob-prototype) so that
        # sceny steps like "- test_step_1" can reference scenario-defined entities (and keep their args),
        # rather than being treated as a psake task name.
        $Context['ScenarioItemDefinitions'] = $scenarioConfig
        foreach ($key in $scenarioConfig.Keys) {
            Add-JaxScenarioEntities -Entities ([ref]$entities) -Result (Convert-JaxScenarioItemToRunEntity -Key $key -Value $scenarioConfig[$key] -ScenarioName $Scenario -ProvenancePath $ProvenancePath -Context $Context)
        }
    } elseif ($scenarioConfig -is [System.Collections.IEnumerable] -and $scenarioConfig -isnot [string]) {
        $index = 0
        foreach ($item in $scenarioConfig) {
            # A plain string already carries its stable task/script identity.
            # Using synthetic item_N keys makes list-tasks leak item_0 and lets
            # `-only TaskName` select both the scenario wrapper and the same
            # discovered psake task, executing it twice.
            $itemKey = "item_$index"
            if ($item -is [string] -and -not [string]::IsNullOrWhiteSpace($item)) {
                $itemKey = $item.Trim()
            }
            Add-JaxScenarioEntities -Entities ([ref]$entities) -Result (Convert-JaxScenarioItemToRunEntity -Key $itemKey -Value $item -ScenarioName $Scenario -ProvenancePath $ProvenancePath -Context $Context)
            $index++
        }
    } else {
        Add-JaxScenarioEntities -Entities ([ref]$entities) -Result (Convert-JaxScenarioItemToRunEntity -Key $Scenario -Value $scenarioConfig -ScenarioName $Scenario -ProvenancePath $ProvenancePath -Context $Context)
    }

    Invoke-JaxHooks -Name 'AfterSequenceResolve' -Context $Context -Data @{
        FlowConfig     = $FlowConfig
        Scenario       = $Scenario
        Entities       = $entities
        FlowConfigPath = $ProvenancePath
    }

    return $entities
}
