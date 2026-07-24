function Write-JaxRunHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [Parameter(Mandatory = $true)]
        [object] $SelectedEnv,
        [Parameter(Mandatory = $true)]
        [object] $FlowConfigEntry,
        [System.Collections.IDictionary] $Config,
        [System.Collections.IDictionary] $Resolved = @{}
    )

    # Quiet mode: skip the framed run-settings box entirely.
    if ($null -ne $Resolved -and $Resolved.Contains('quiet') -and [bool]$Resolved['quiet']) {
        $isOverride = $Resolved.Contains('noQuiet') -and [bool]$Resolved['noQuiet']
        $isVerbose = $VerbosePreference -eq 'Continue' -or $DebugPreference -eq 'Continue'
        if (-not $isOverride -and -not $isVerbose) { return }
    }

    $envName = $null
    if ($null -ne $SelectedEnv -and $SelectedEnv.PSObject.Properties.Match('Name').Count -gt 0) {
        $envName = [string]$SelectedEnv.Name
    }
    $flowName = $null
    if ($null -ne $FlowConfigEntry -and $FlowConfigEntry.PSObject.Properties.Match('Configuration').Count -gt 0) {
        $flowName = [string]$FlowConfigEntry.Configuration
    }
    if ([string]::IsNullOrWhiteSpace($flowName) -and $null -ne $FlowConfigEntry -and $FlowConfigEntry.PSObject.Properties.Match('Name').Count -gt 0) {
        $flowName = [string]$FlowConfigEntry.Name
    }

    # Set terminal tab title for supported interactive terminals (Ghostty/cmux etc.).
    # Never affects CI, Docker, redirected output, or non-supported terminals.
    try {
        $initialTitle = Get-JaxTabTitleForRun -EnvName $envName -FlowName $flowName
        if (-not [string]::IsNullOrWhiteSpace($initialTitle)) {
            Set-JaxTerminalTabTitle -Title $initialTitle
        }
    } catch {
        # best effort only
    }

    $gitBranch = $null
    $gitCommit = $null
    try {
        $gitBranch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null)
        $gitCommit = (& git -C $RepoRoot rev-parse --short HEAD 2>$null)
    } catch {
        # ignore
    }
    if ($gitBranch) { $gitBranch = ([string]$gitBranch).Trim() }
    if ($gitCommit) { $gitCommit = ([string]$gitCommit).Trim() }

    $gout = $null
    if ($Resolved -and $Resolved.ContainsKey('gout')) {
        $gout = [string]$Resolved['gout']
    }

    $vaultState = 'unknown'
    try {
        if ($Config -and $Config.ContainsKey('plugins')) {
            $plugins = $Config['plugins']
            if ($plugins -is [System.Collections.IDictionary]) {
                $enabled = @()
                $disabled = @()
                if ($plugins.ContainsKey('enabled')) { $enabled = @($plugins['enabled']) }
                if ($plugins.ContainsKey('disabled')) { $disabled = @($plugins['disabled']) }
                if ($disabled -contains 'vault') { $vaultState = 'disabled' }
                elseif ($enabled -contains 'vault') { $vaultState = 'enabled' }
            }
        }
    } catch {
        # ignore
    }

    # CLI/state override: allow -vault/-novault to temporarily flip vault behavior without modifying config.
    try {
        if ($Resolved -and $Resolved.ContainsKey('vaultEnabledOverride') -and $Resolved['vaultEnabledOverride'] -is [bool]) {
            $vaultState = if ([bool]$Resolved['vaultEnabledOverride']) { 'enabled' } else { 'disabled' }
        } elseif ($Resolved -and $Resolved.ContainsKey('novault') -and [bool]$Resolved['novault']) {
            $vaultState = 'disabled'
        } elseif ($Resolved -and $Resolved.ContainsKey('vault') -and [bool]$Resolved['vault']) {
            $vaultState = 'enabled'
        }
    } catch {
        # ignore
    }

    Write-Host ''
    Write-Host '┌─── 🏃 Run settings ───'
    if (-not [string]::IsNullOrWhiteSpace($envName)) {
        if (-not [string]::IsNullOrWhiteSpace($flowName)) {
            Write-Host ("│ 📜 Env: {0} [{1}]" -f $envName, $flowName)
        } else {
            Write-Host ("│ 📜 Env: {0}" -f $envName)
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($gout)) {
        Write-Host ("│ 🍰 Gout: {0}" -f $gout)
    }
    if (-not [string]::IsNullOrWhiteSpace($gitBranch) -or -not [string]::IsNullOrWhiteSpace($gitCommit)) {
        $gitText = if ($gitBranch -and $gitCommit) { "🌿 $gitBranch (commit '$gitCommit')" } elseif ($gitBranch) { "🌿 $gitBranch" } else { "commit '$gitCommit'" }
        Write-Host ("│ 🐙 Git: {0}" -f $gitText)
    }
    Write-Host ("│ 🔐 Vault: {0}" -f $vaultState)
    Write-Host '└──────────────────────'
    Write-Host ''
}
