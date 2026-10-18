function Get-JaxEnvironmentTaskKeys {
    <#
    .SYNOPSIS
    Return the selectable task keys (default scenario plus discovered tasks) of one environment.

    .OUTPUTS
    A hashtable with Keys (string[]) and Message (why Keys is empty, or $null).
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Config,
        [Parameter(Mandatory = $true)]
        $Environment,
        [string] $FlowOverride
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters

    $skipEnvRoot = $false
    if ($Environment.PSObject.Properties.Match('SkipEnvRoot').Count -gt 0 -and $Environment.SkipEnvRoot) {
        $skipEnvRoot = $true
    }
    if ($Environment.PSObject.Properties.Match('IsDummy').Count -gt 0 -and $Environment.IsDummy) {
        $skipEnvRoot = $true
    }
    $isComputedEnv = $false
    if ($Environment.PSObject.Properties.Match('IsComputed').Count -gt 0 -and $Environment.IsComputed) {
        $isComputedEnv = $true
    }

    if ([string]::IsNullOrWhiteSpace($FlowOverride)) {
        $flowConfigEntry = Resolve-JaxSelectedFlowConfig -Environment $Environment @commonParams
    } else {
        $flowConfigEntry = Resolve-JaxSelectedFlowConfig -Environment $Environment -PreferredConfig $FlowOverride @commonParams
    }

    $allowMissingFlowConfig = $skipEnvRoot -or $isComputedEnv
    if ($null -eq $flowConfigEntry -and -not $allowMissingFlowConfig) {
        return @{ Keys = @(); Message = "No flow configs found for environment '$($Environment.Name)'." }
    }

    $flowConfig = $null
    if ($null -ne $flowConfigEntry) {
        $flowConfig = Get-JaxFlowConfig -Paths $flowConfigEntry.ConfigPaths -ExpandVariables:$false @commonParams
    }

    $envDir = $null
    if ($null -ne $flowConfigEntry -and $flowConfigEntry.PSObject.Properties.Match('EnvDirPath').Count -gt 0) {
        $envDir = $flowConfigEntry.EnvDirPath
    } elseif ($Environment.PSObject.Properties.Match('EnvDir').Count -gt 0) {
        $envDir = $Environment.EnvDir
    }
    $context = @{
        RepoRoot             = $RepoRoot
        EnvDir               = $envDir
        Config               = $Config
        SuppressRunConfigLog = $true
        SkipEnvRoot          = $skipEnvRoot
    }

    $discoveredEntities = @(Get-JaxDiscoveredRunEntities -RepoRoot $RepoRoot -EnvDir $envDir -Config $Config -SkipEnvRoot:$skipEnvRoot @commonParams)
    $context['DiscoveredEntities'] = $discoveredEntities
    $context['DiscoveredEntityIndex'] = New-JaxRunEntityIndex -Entities $discoveredEntities

    $entities = @()
    if ($null -ne $flowConfig) {
        # Best effort, as list-tasks always was: a plugin hook may throw (for
        # example bob's git check when it cannot prompt). -ErrorAction alone only
        # swallows that throw when no caller has a try/catch, so catch it here.
        try {
            $entities += Get-JaxScenarioRunEntities -FlowConfig $flowConfig -Scenario 'default' -Context $context -ProvenancePath $flowConfigEntry.ConfigPath -ErrorAction SilentlyContinue @commonParams
        } catch {
            Write-Verbose "Default scenario of '$($Environment.Name)' not expanded: $($_.Exception.Message)"
        }
    }
    if ($discoveredEntities.Count -gt 0) {
        $entities += $discoveredEntities
    }

    $keys = @(Get-JaxRunEntityKeys -Entities $entities -IncludeAliases)
    if ($keys.Count -eq 0) {
        return @{ Keys = @(); Message = 'No tasks found.' }
    }
    return @{ Keys = $keys; Message = $null }
}
