function Get-JaxSequenceKeyCandidates {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [System.Collections.IDictionary] $Config,
        [Parameter(Mandatory = $true)]
        [string] $EnvWithOptionalFlow,
        [string] $Scenario
    )

    if ($null -eq $Config) {
        $Config = Get-JaxConfig -RepoRoot $RepoRoot
    }

    $configNormalized = Convert-JaxConfig -Config $Config
    $envs = Get-JaxEnvironments -RepoRoot $RepoRoot -Config $configNormalized
    if ($null -eq $envs -or $envs.Count -eq 0) {
        return @()
    }

    $envName = $EnvWithOptionalFlow
    $flowOverride = $null

    # Format: "<env>/<flow>" where <env> itself can contain slashes (e.g. empty-template/play/build).
    if (-not [string]::IsNullOrWhiteSpace($EnvWithOptionalFlow) -and $EnvWithOptionalFlow.Contains('/')) {
        $parts = @($EnvWithOptionalFlow -split '/')
        if ($parts.Count -ge 2) {
            $maybeFlow = $parts[$parts.Count - 1]
            $maybeEnv = ($parts[0..($parts.Count - 2)] -join '/')
            if (-not [string]::IsNullOrWhiteSpace($maybeFlow) -and -not [string]::IsNullOrWhiteSpace($maybeEnv)) {
                $envCandidate = $envs | Where-Object { $_.Name -eq $maybeEnv } | Select-Object -First 1
                if ($null -ne $envCandidate) {
                    $hasFlow = $false
                    foreach ($fc in @($envCandidate.FlowConfigs)) {
                        if ($null -ne $fc -and $fc.PSObject.Properties.Match('Configuration').Count -gt 0) {
                            if ([string]$fc.Configuration -eq $maybeFlow) {
                                $hasFlow = $true
                                break
                            }
                        }
                    }
                    if ($hasFlow) {
                        $envName = $maybeEnv
                        $flowOverride = $maybeFlow
                    }
                }
            }
        }
    }

    $selectedEnv = $envs | Where-Object { $_.Name -eq $envName } | Select-Object -First 1
    if ($null -eq $selectedEnv) {
        return @()
    }

    $preferredConfig = if ([string]::IsNullOrWhiteSpace($flowOverride)) { 'build' } else { $flowOverride }
    $flowConfigEntry = Resolve-JaxSelectedFlowConfig -Environment $selectedEnv -PreferredConfig $preferredConfig
    if ($null -eq $flowConfigEntry) {
        return @()
    }

    $flow = Get-JaxFlowConfig -Paths $flowConfigEntry.ConfigPaths -ExpandVariables:$false
    if ($flow -isnot [System.Collections.IDictionary] -or -not $flow.Contains('suite')) {
        return @()
    }
    $suite = $flow['suite']
    if ($suite -isnot [System.Collections.IDictionary]) {
        return @()
    }

    $index = @{}

    function Add-OrUpdateCandidate {
        param(
            [Parameter(Mandatory = $true)] [string] $Name,
            [Parameter(Mandatory = $true)] [string] $Kind,
            [string] $ToolTip
        )
        $weight = 0
        switch ($Kind) {
            'build' { $weight = 10 }
            'scenario' { $weight = 20 }
            'library' { $weight = 30 }
            default { $weight = 5 }
        }

        if ($index.ContainsKey($Name)) {
            $existing = $index[$Name]
            if ($null -ne $existing -and $existing.PSObject.Properties.Match('_weight').Count -gt 0) {
                if ([int]$existing._weight -ge $weight) {
                    return
                }
            }
        }

        $index[$Name] = [pscustomobject]@{
            Name    = $Name
            Kind    = $Kind
            ToolTip = $ToolTip
            _weight = $weight
        }
    }

    $sourceTip = $flowConfigEntry.ConfigPath

    # Build chain keys: configurable section names (defaults: build, modules)
    $buildSection = $null
    $buildSectionName = $null
    $buildSectionNames = Get-JaxBuildSectionNames -Config $configNormalized
    foreach ($sectionName in @($buildSectionNames)) {
        if ($suite.Contains($sectionName)) {
            $buildSection = $suite[$sectionName]
            $buildSectionName = [string]$sectionName
            break
        }
    }
    if ($null -ne $buildSection) {
        $buildTipPrefix = if ($buildSectionName -eq 'build') { 'build' } else { "build($buildSectionName)" }
        if ($buildSection -is [System.Collections.IDictionary]) {
            foreach ($k in @($buildSection.Keys)) {
                if ([string]::IsNullOrWhiteSpace([string]$k)) { continue }
                Add-OrUpdateCandidate -Name ([string]$k) -Kind 'build' -ToolTip "$buildTipPrefix → $sourceTip"
            }
        } elseif ($buildSection -is [System.Collections.IEnumerable] -and $buildSection -isnot [string]) {
            foreach ($item in @($buildSection)) {
                if ($item -is [string] -and -not [string]::IsNullOrWhiteSpace($item)) {
                    Add-OrUpdateCandidate -Name ([string]$item) -Kind 'build' -ToolTip "$buildTipPrefix → $sourceTip"
                }
            }
        }
    }

    # Scenario keys: suite.scenarios.<scenario>
    if ($suite.Contains('scenarios')) {
        $scenarios = $suite['scenarios']
        if ($scenarios -is [System.Collections.IDictionary]) {
            $scenarioToUse = $Scenario
            if ([string]::IsNullOrWhiteSpace($scenarioToUse)) {
                if ($scenarios.Contains('default')) { $scenarioToUse = 'default' } else { $scenarioToUse = ($scenarios.Keys | Select-Object -First 1) }
            }
            if (-not [string]::IsNullOrWhiteSpace($scenarioToUse) -and $scenarios.Contains($scenarioToUse)) {
                $scenarioConfig = $scenarios[$scenarioToUse]
                if ($scenarioConfig -is [System.Collections.IDictionary]) {
                    foreach ($k in @($scenarioConfig.Keys)) {
                        if ([string]::IsNullOrWhiteSpace([string]$k)) { continue }
                        Add-OrUpdateCandidate -Name ([string]$k) -Kind 'scenario' -ToolTip "scenario:$scenarioToUse → $sourceTip"
                    }
                } elseif ($scenarioConfig -is [System.Collections.IEnumerable] -and $scenarioConfig -isnot [string]) {
                    foreach ($item in @($scenarioConfig)) {
                        if ($item -is [string] -and -not [string]::IsNullOrWhiteSpace($item)) {
                            Add-OrUpdateCandidate -Name ([string]$item) -Kind 'scenario' -ToolTip "scenario:$scenarioToUse → $sourceTip"
                            continue
                        }
                        if ($item -is [System.Collections.IDictionary] -and $item.Count -eq 1) {
                            $ik = $item.Keys | Select-Object -First 1
                            if (-not [string]::IsNullOrWhiteSpace([string]$ik)) {
                                Add-OrUpdateCandidate -Name ([string]$ik) -Kind 'scenario' -ToolTip "scenario:$scenarioToUse → $sourceTip"
                            }
                        }
                    }
                }
            }
        }
    }

    # Library keys: suite.library
    if ($suite.Contains('library')) {
        $library = $suite['library']
        if ($library -is [System.Collections.IDictionary]) {
            foreach ($k in @($library.Keys)) {
                if ([string]::IsNullOrWhiteSpace([string]$k)) { continue }
                Add-OrUpdateCandidate -Name ([string]$k) -Kind 'library' -ToolTip "library → $sourceTip"
            }
        }
    }

    $values = @($index.Values | ForEach-Object {
        if ($null -eq $_) { return }
        $o = $_ | Select-Object -Property Name, Kind, ToolTip
        return $o
    })
    return @($values | Sort-Object -Property Name -Unique)
}
