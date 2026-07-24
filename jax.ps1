[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $choices = @(
                'help', 'init',
                'env', 'list-envs', 'list-tasks',
                'run', 'r', 'invoke', 'plan', 'autocomplete', 'create-flavour', 'settings', 'skill', 'info'
            )
            foreach ($c in $choices) {
                if ([string]::IsNullOrWhiteSpace($wordToComplete) -or $c -like "$wordToComplete*") {
                    [System.Management.Automation.CompletionResult]::new($c, $c, 'ParameterValue', $c)
                }
            }
        })]
    [string] $Command,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $CommandArgs,

    # Compatibility core flags MUST be static so DynamicParam can resolve the plan.
    [Alias('e')]
    [string] $env,
    [string] $client,
    [Alias('s')]
    [string] $scenario,
    [Alias('f')]
    [string] $from,
    [Alias('t')]
    [string] $to,
    [Alias('o')]
    [string[]] $only,
    [Alias('nb')]
    [switch] $noBuild,
    [Alias('bo')]
    [switch] $buildChainOnly,
    [Alias('nc')]
    [switch] $noCache,

    # Shortcut flags
    # -sc <name>  : expand a saved shortcut (injects its saved args into the invocation)
    # -ssc / -csc / -createShortCut <name> : save the current command as a shortcut (validate, save, exit)
    [Alias('sc')]
    [string] $Shortcut,
    [Alias('ssc', 'csc', 'createShortCut')]
    [string] $SaveShortcut,
    [Alias('rsc')]
    [string] $RemoveShortcut,

    # Plan detail level
    [switch] $Detailed,

    # Quiet mode: minimal output for token-optimized usage (RTK-friendly).
    # Persisted via 'jax settings set quiet on'. Override saved-on for one run with -NoQuiet/-nq.
    # -Verbose/-Debug always force full output.
    [Alias('q')]
    [switch] $Quiet,
    [Alias('nq', 'noq')]
    [switch] $NoQuiet,

    # Target repository. The Jax installation remains rooted at $PSScriptRoot.
    [Alias('C')]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $RepoRoot
)

dynamicparam {
    # Compatibility DynamicParam:
    # - also expose task/script parameters from the resolved plan as native parameters
    try {
        # IMPORTANT: import core into the *global* session state so plugin modules (imported as separate modules)
        # can resolve core functions like Register-JaxPlugin/Register-JaxScenarioResolver during their module init.
        Import-Module (Join-Path $PSScriptRoot 'core/Jax.Core.psm1') -Global -Force -ErrorAction Stop
    } catch {
        return (New-Object System.Management.Automation.RuntimeDefinedParameterDictionary)
    }

    $resolved = Resolve-JaxCliCommand -Command $Command -CommandArgs $CommandArgs
    $resolvedCmd = $resolved.Command
    if ($resolvedCmd) { $resolvedCmd = $resolvedCmd.ToLowerInvariant() }

    $hasRunSelectors = -not [string]::IsNullOrWhiteSpace($env) -or
        -not [string]::IsNullOrWhiteSpace($client) -or
        -not [string]::IsNullOrWhiteSpace($scenario) -or
        -not [string]::IsNullOrWhiteSpace([string]$only) -or
        -not [string]::IsNullOrWhiteSpace($from) -or
        -not [string]::IsNullOrWhiteSpace($to)

    # IMPORTANT: DynamicParam executes before the begin{} fallback that defaults to 'run'.
    # If the user invokes jax without an explicit command (e.g. `./jax/jax.ps1 -env X -only Y`),
    # we must still expose dynamic params for run/plan scenarios.
    if ([string]::IsNullOrWhiteSpace($resolvedCmd)) {
        if ($hasRunSelectors) {
            $resolvedCmd = 'run'
        }
    }

    # Keep the historic implicit task form `jax info -env <env>` working. The
    # diagnostic command is intentionally the bare form, without run selectors.
    if ($resolvedCmd -eq 'info' -and $hasRunSelectors) {
        $resolvedCmd = 'run'
    }

    $supportsRunParams = $resolvedCmd -eq 'run' -or $resolvedCmd -eq 'plan'
    if (-not $supportsRunParams) {
        return (New-Object System.Management.Automation.RuntimeDefinedParameterDictionary)
    }

    function New-JaxRuntimeParam {
        param(
            [Parameter(Mandatory = $true)] [string] $Name,
            [Parameter(Mandatory = $true)] [Type] $Type,
            [string[]] $Aliases,
            [string] $HelpMessage,
            [string[]] $ValidateSetValues
        )
        $attrs = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $paramAttr = New-Object System.Management.Automation.ParameterAttribute
        $paramAttr.Mandatory = $false
        if (-not [string]::IsNullOrWhiteSpace($HelpMessage)) {
            $paramAttr.HelpMessage = $HelpMessage
        }
        $attrs.Add($paramAttr) | Out-Null
        if ($Aliases -and $Aliases.Count -gt 0) {
            $attrs.Add([System.Management.Automation.AliasAttribute]::new($Aliases)) | Out-Null
        }
        if ($ValidateSetValues -and $ValidateSetValues.Count -gt 0) {
            $attrs.Add([System.Management.Automation.ValidateSetAttribute]::new($ValidateSetValues)) | Out-Null
        }
        return [System.Management.Automation.RuntimeDefinedParameter]::new($Name, $Type, $attrs)
    }

    $dict = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

    # ---- task/script params (resolved from plan) ----
    try {
        $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
        $repoRootParams = @{}
        if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
            $repoRootParams.StartPath = $RepoRoot
            $repoRootParams.Exact = $true
        }
        $repoRoot = Get-JaxRepoRoot @repoRootParams
        $config = Get-JaxConfig -RepoRoot $repoRoot @commonParams
        Import-JaxPlugins -Config $config -RepoRoot $repoRoot @commonParams | Out-Null

        # Use $resolved.Args so positional env/task shorthand (e.g. `jax operations/wtw PublishWtw`)
        # is visible to task/script param discovery during DynamicParam tab completion.
        $parsed = Resolve-JaxCliArgs -Args $resolved.Args @commonParams
        $cliOptions = $parsed.Values
        # Static core flags win over legacy parsing
        if ($PSBoundParameters.ContainsKey('env')) { $cliOptions['env'] = $PSBoundParameters['env'] }
        if ($PSBoundParameters.ContainsKey('client')) { $cliOptions['client'] = $PSBoundParameters['client'] }
        if ($PSBoundParameters.ContainsKey('scenario')) { $cliOptions['scenario'] = $PSBoundParameters['scenario'] }
        if ($PSBoundParameters.ContainsKey('from')) { $cliOptions['from'] = $PSBoundParameters['from'] }
        if ($PSBoundParameters.ContainsKey('to')) { $cliOptions['to'] = $PSBoundParameters['to'] }
        if ($PSBoundParameters.ContainsKey('only')) { $cliOptions['only'] = $PSBoundParameters['only'] }
        if ($PSBoundParameters.ContainsKey('noBuild')) { $cliOptions['noBuild'] = [bool]$PSBoundParameters['noBuild'] }
        if ($PSBoundParameters.ContainsKey('buildChainOnly')) { $cliOptions['buildChainOnly'] = [bool]$PSBoundParameters['buildChainOnly'] }
        if ($PSBoundParameters.ContainsKey('noCache')) { $cliOptions['noCache'] = [bool]$PSBoundParameters['noCache'] }
        if ($PSBoundParameters.ContainsKey('Quiet')) { $cliOptions['quiet'] = [bool]$PSBoundParameters['Quiet'] }
        if ($PSBoundParameters.ContainsKey('NoQuiet')) { $cliOptions['noQuiet'] = [bool]$PSBoundParameters['NoQuiet'] }

        # ---- plugin/core CLI params (always) ----
        # Expose registered CLI params (including plugin-defined flags) as real PowerShell parameters
        # so standard parameter-name completion works.
        $staticParamNames = @()
        try {
            $staticParamNames = @($MyInvocation.MyCommand.Parameters.Keys)
        } catch {
            $staticParamNames = @()
        }
        $staticLower = @($staticParamNames | ForEach-Object { $_.ToLowerInvariant() })

        foreach ($def in @(Get-JaxCliParameters)) {
            if ($null -eq $def) { continue }
            $pName = [string]$def.Name
            if ([string]::IsNullOrWhiteSpace($pName)) { continue }
            $pLower = $pName.ToLowerInvariant()
            if ($reservedLower -contains $pLower) { continue }
            if ($staticLower -contains $pLower) { continue }
            if ($dict.ContainsKey($pName)) { continue }

            $pType = if ($def.Type -eq 'switch') { [switch] } else { [string] }
            $aliases = @()
            try {
                if ($def.Aliases) { $aliases = @($def.Aliases) }
            } catch {
                $aliases = @()
            }
            $dict.Add($pName, (New-JaxRuntimeParam -Name $pName -Type $pType -Aliases $aliases -HelpMessage '' -ValidateSetValues @()))
        }

        # Only compute dynamic task/script parameters when the user
        # narrowed execution with -only/-from/-to (otherwise tab completion becomes slow/noisy).
        # IMPORTANT: we check BOTH static params AND the legacy parsed args because in scripts
        # PowerShell may still leave some flags in $CommandArgs.
        $hasNarrowing = -not [string]::IsNullOrWhiteSpace([string]$cliOptions['only']) -or
        -not [string]::IsNullOrWhiteSpace([string]$cliOptions['from']) -or
        -not [string]::IsNullOrWhiteSpace([string]$cliOptions['to']) -or
        -not [string]::IsNullOrWhiteSpace([string]$only) -or
        -not [string]::IsNullOrWhiteSpace([string]$from) -or
        -not [string]::IsNullOrWhiteSpace([string]$to)
        if (-not $hasNarrowing) {
            return $dict
        }

        $envs = Get-JaxEnvironments -RepoRoot $repoRoot -Config $config @commonParams
        $selection = Resolve-JaxEnvSelection -Environments $envs -Env $cliOptions['env'] -Client $cliOptions['client'] @commonParams
        $selectedEnv = $selection.Environment
        if ($null -ne $selectedEnv) {
            $skipEnvRoot = $false
            if ($selectedEnv.PSObject.Properties.Match('SkipEnvRoot').Count -gt 0 -and $selectedEnv.SkipEnvRoot) {
                $skipEnvRoot = $true
            }
            if ($selectedEnv.PSObject.Properties.Match('IsDummy').Count -gt 0 -and $selectedEnv.IsDummy) {
                $skipEnvRoot = $true
            }

            $flowConfigEntry = Resolve-JaxSelectedFlowConfig -Environment $selectedEnv -PreferredConfig $selection.FlowOverride @commonParams
            if ($null -eq $flowConfigEntry -and -not $skipEnvRoot) {
                return $dict
            }

            $flowConfig = $null
            if ($null -ne $flowConfigEntry) {
                $flowConfig = Get-JaxFlowConfig -Paths $flowConfigEntry.ConfigPaths -ExpandVariables:$false @commonParams
            }

            $envDir = $null
            if ($null -ne $flowConfigEntry -and $flowConfigEntry.PSObject.Properties.Match('EnvDirPath').Count -gt 0) {
                $envDir = $flowConfigEntry.EnvDirPath
            } elseif ($selectedEnv.PSObject.Properties.Match('EnvDir').Count -gt 0) {
                $envDir = $selectedEnv.EnvDir
            }

            $context = @{
                RepoRoot             = $repoRoot
                EnvDir               = $envDir
                Config               = $config
                NoCache              = $true
                SkipEnvRoot          = $skipEnvRoot
                # DynamicParam evaluation must not create run logs / side effects.
                SuppressRunConfigLog = $true
            }
            # Used by runners to resolve relative paths (scripts/psakefile) against the env folder.
            if (-not [string]::IsNullOrWhiteSpace($envDir)) {
                $context['WorkingDir'] = $envDir
            } else {
                $context['WorkingDir'] = $repoRoot
            }
            if ($null -ne $flowConfigEntry -and $flowConfigEntry.PSObject.Properties.Match('EnvDirPath').Count -gt 0) {
                $defaultPsakeFile = Join-Path $flowConfigEntry.EnvDirPath 'psakefile.ps1'
                if (Test-Path -LiteralPath $defaultPsakeFile -PathType Leaf) {
                    $context['PsakeFile'] = $defaultPsakeFile
                }
            }

            # Propagate Debug/Verbose if present in PSBoundParameters
            if ($PSBoundParameters.ContainsKey('Debug') -and $PSBoundParameters['Debug']) {
                $context['Debug'] = $true
                $DebugPreference = 'Continue'
            }
            if ($PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose']) {
                $context['Verbose'] = $true
                $VerbosePreference = 'Continue'
            }

            $discoveredEntities = Get-JaxDiscoveredRunEntities -RepoRoot $repoRoot -EnvDir $envDir -Config $config -SkipEnvRoot:$skipEnvRoot @commonParams
            $context['DiscoveredEntities'] = $discoveredEntities
            $context['DiscoveredEntityIndex'] = New-JaxRunEntityIndex -Entities $discoveredEntities

            $scenarioEntities = @()
            $buildEntities = @()
            if ($null -ne $flowConfig) {
                $scenarioEntities = Get-JaxScenarioRunEntities -FlowConfig $flowConfig -Scenario $cliOptions['scenario'] -Context $context -ProvenancePath $flowConfigEntry.ConfigPath @commonParams
                $context['ScenarioEntityIndex'] = New-JaxRunEntityIndex -Entities $scenarioEntities
                $buildEntities = Get-JaxBuildRunEntities -FlowConfig $flowConfig -Config $config -Context $context -ProvenancePath $flowConfigEntry.ConfigPath @commonParams
            }
            $plan = Resolve-JaxRunPlan -BuildEntities $buildEntities -ScenarioEntities $scenarioEntities -IndividualEntities $discoveredEntities -NoBuild:([bool]$cliOptions['noBuild']) -BuildChainOnly:([bool]$cliOptions['buildChainOnly']) -Only $cliOptions['only'] -From $cliOptions['from'] -To $cliOptions['to'] -Context $context @commonParams

            $reserved = @('Command', 'CommandArgs', 'env', 'client', 'scenario', 'from', 'to', 'only', 'noBuild', 'buildChainOnly', 'noCache', 'Detailed', 'Quiet', 'NoQuiet', 'RepoRoot')
            $reservedLower = @($reserved | ForEach-Object { $_.ToLowerInvariant() })

            foreach ($entity in @($plan)) {
                if ($null -eq $entity -or $entity -isnot [System.Collections.IDictionary]) {
                    continue
                }

                # psake task params from Definition.Parameters (properties{} parsing)
                if ($entity.Contains('Definition') -and $entity['Definition'] -is [System.Collections.IDictionary]) {
                    $def = $entity['Definition']
                    if ($def.Contains('Parameters') -and $def['Parameters'] -is [System.Collections.IEnumerable]) {
                        foreach ($p in @($def['Parameters'])) {
                            if ($p -isnot [System.Collections.IDictionary]) {
                                continue
                            }
                            $pName = [string]$p['Name']
                            if ([string]::IsNullOrWhiteSpace($pName)) { continue }
                            if ($reservedLower -contains $pName.ToLowerInvariant()) { continue }
                            if ($dict.ContainsKey($pName)) { continue }
                            $typeName = [string]$p['Type']
                            $paramType = [object]
                            if (-not [string]::IsNullOrWhiteSpace($typeName)) {
                                try { $paramType = $typeName -as [type] } catch { $paramType = [object] }
                                if ($null -eq $paramType) { $paramType = [object] }
                            }
                            $help = [string]$p['Description']
                            $dict.Add($pName, (New-JaxRuntimeParam -Name $pName -Type $paramType -Aliases @() -HelpMessage $help -ValidateSetValues @()))
                        }
                    }
                }

                # script params via Get-Command metadata (ps1 only)
                if ($entity.Contains('Script') -and $entity['Script'] -is [string] -and -not [string]::IsNullOrWhiteSpace($entity['Script'])) {
                    $scriptPath = Resolve-JaxRepoRootedPath -Path $entity['Script'] -RepoRoot $repoRoot -WorkingDir $envDir @commonParams
                    if (Test-Path -Path $scriptPath -PathType Leaf) {
                        $cmdInfo = Get-Command -Name $scriptPath -ErrorAction SilentlyContinue
                        if ($cmdInfo -and $cmdInfo.Parameters) {
                            foreach ($kv in $cmdInfo.Parameters.GetEnumerator()) {
                                $pName = [string]$kv.Key
                                if ([string]::IsNullOrWhiteSpace($pName)) { continue }
                                if ($reservedLower -contains $pName.ToLowerInvariant()) { continue }
                                if ($dict.ContainsKey($pName)) { continue }
                                $meta = $kv.Value
                                $pType = [object]
                                try { $pType = $meta.ParameterType } catch { $pType = [object] }
                                $dict.Add($pName, (New-JaxRuntimeParam -Name $pName -Type $pType -Aliases @() -HelpMessage '' -ValidateSetValues @()))
                            }
                        }
                    }
                }
            }
        }
    } catch {
        # Best-effort only (tab completion should never throw).
    }

    return $dict
}

begin {
    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    $coreModulePath = Join-Path $PSScriptRoot 'core/Jax.Core.psm1'
    try {
        Import-Module $coreModulePath -Global -Force -ErrorAction Stop
    } catch {
        throw "Failed to import Jax core module '$coreModulePath': $($_.Exception.Message)"
    }

    $repoRootParams = @{}
    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        $repoRootParams.StartPath = $RepoRoot
        $repoRootParams.Exact = $true
    }
    $jaxRepoRoot = Get-JaxRepoRoot @repoRootParams

    # ---- Shortcut: expand -Shortcut/-sc before command resolution ----
    if (-not [string]::IsNullOrWhiteSpace($Shortcut)) {
        try {
            $expanded = Expand-JaxCliShortcut -Name $Shortcut -CommonParams $commonParams -Command $Command -CommandArgs $CommandArgs -RepoRoot $jaxRepoRoot
            $Command = $expanded.Command
            $CommandArgs = $expanded.CommandArgs
        } catch {
            throw "Failed to expand shortcut '$Shortcut': $_"
        }
    }

    $hasRunSelectors = -not [string]::IsNullOrWhiteSpace($env) -or
        -not [string]::IsNullOrWhiteSpace($client) -or
        -not [string]::IsNullOrWhiteSpace($scenario) -or
        -not [string]::IsNullOrWhiteSpace([string]$only) -or
        -not [string]::IsNullOrWhiteSpace($from) -or
        -not [string]::IsNullOrWhiteSpace($to)
    if ($Command -eq 'info' -and $hasRunSelectors) {
        $Command = 'run'
        $CommandArgs = @('info') + @($CommandArgs)
    }
    $resolvedCommand = Resolve-JaxCliCommand -Command $Command -CommandArgs $CommandArgs

    # ---- Shortcut: save -SaveShortcut/-ssc (validate-then-save, no execution) ----
    if (-not [string]::IsNullOrWhiteSpace($SaveShortcut)) {
        try {
            $argsToSave = Get-JaxShortcutArgsToSave -Command $Command -env $env -client $client -scenario $scenario `
                -only $only -from $from -to $to -noBuild:$noBuild -buildChainOnly:$buildChainOnly -noCache:$noCache `
                -CommandArgs $CommandArgs
            Save-JaxShortcutToConfig -Name $SaveShortcut -CommonParams $commonParams -ArgsToSave $argsToSave -RepoRoot $jaxRepoRoot
        } catch {
            throw "Failed to save shortcut '$SaveShortcut': $_"
        }
        return
    }

    # ---- Shortcut: remove -RemoveShortcut/-rsc (no execution) ----
    if (-not [string]::IsNullOrWhiteSpace($RemoveShortcut)) {
        try {
            Remove-JaxShortcutFromConfig -Name $RemoveShortcut -CommonParams $commonParams -RepoRoot $jaxRepoRoot
        } catch {
            throw "Failed to remove shortcut '$RemoveShortcut': $_"
        }
        return
    }

    # Handle implicit 'run' or default to 'list-envs'
    if ([string]::IsNullOrWhiteSpace($resolvedCommand.Command)) {
        if ($hasRunSelectors) {
            $resolvedCommand.Command = 'run'
        } else {
            $resolvedCommand.Command = 'list-envs'
        }
    }

    $Command = $resolvedCommand.Command
    $CommandArgs = $resolvedCommand.Args
    if ($Command -eq 'plan') {
        $CommandArgs = @('-plan') + @($CommandArgs)
        $Command = 'run'
    }

    function Show-JaxHelp {
        try {
            $repoRoot = $jaxRepoRoot
            $config = Get-JaxConfig -RepoRoot $repoRoot @commonParams
            Import-JaxPlugins -Config $config -RepoRoot $repoRoot @commonParams | Out-Null
        } catch {
        }

        Write-Host "Jax CLI"
        Write-Host "Usage: jax [-RepoRoot <path> | -C <path>] <command> [options]"
        Write-Host "Commands:"
        Write-Host "  init       Initialize repo scaffold"
        # Write-Host "  init-compat  Generate a compatibility config"
        # Write-Host "  init-legacy  Alias for init-compat"
        Write-Host "  env init  Initialize environment scaffold"
        Write-Host "  list-envs  List environments discovered under env/"
        Write-Host "  run (r, invoke)  Run flows and scenarios (explicit)"
        Write-Host "  plan       Print the run plan without executing"
        Write-Host "  autocomplete  Register jax tab completion for the current session"
        Write-Host "  info       Show installed runtime, repository, and configuration diagnostics"
        Write-Host "  skill      Install the bundled AI-agent skill into the target repository"
        Write-Host "  create-flavour  Create a flavour file under configs/jax-flavours"
        Write-Host "  settings   Manage persisted settings (.jax/state.yml)"
        Write-Host ""
        Write-Host "Output flags:"
        Write-Host "  -q  / -Quiet     Minimal output (one-line banners, no framed boxes). Persist with 'jax settings set quiet on'."
        Write-Host "  -nq / -NoQuiet   Force full output for one run (overrides saved quiet)."
        Write-Host "  -Verbose         Always shows full output regardless of quiet setting."
        Write-Host "  -o / -only A,B   Run one selector, or comma/array selectors as an ad-hoc scenario."
        Write-Host "  -C / -RepoRoot   Run against an explicit repository without changing directory."
        Write-Host ""
        Write-Host "Shortcut flags:"
        Write-Host "  -sc <name>   Run a saved shortcut (does not update saved env in .jax/state.yml)"
        Write-Host "  -ssc / -csc / -createShortCut  Save shortcut to .jax/jax.shortcut.yml, exit (no run; state unchanged; jax.config.yml untouched)"
        Write-Host "  -rsc <name>  Remove a saved shortcut in .jax/jax.shortcut.yml (no run; jax.config.yml untouched)"

        $entries = Get-JaxHelpEntries
        if ($entries.Count -gt 0) {
            Write-Host ""
            Write-Host "Plugin commands:"
            foreach ($entry in $entries) {
                Write-Host ("  {0}  {1}" -f $entry.Name, $entry.Summary)
            }
        }
    }

    function Show-JaxSettingsHelp {
        Write-Host "Usage: jax settings <subcommand>"
        Write-Host ""
        Write-Host "  show                    Print current persisted settings (.jax/state.yml)."
        Write-Host "  reset                   Remove .jax/state.yml for the current repo."
        Write-Host "  set <key> [<value>]     Persist a setting (e.g. 'set quiet on', 'set quiet off')."
        Write-Host ""
        Write-Host "Known keys (core scope):"
        Write-Host "  quiet      on|off|true|false   Minimal CLI output (RTK-friendly)."
        Write-Host "  verbose    on|off              Default verbose preference."
        Write-Host "  docker     on|off              Force container runner by default."
    }

    function Show-JaxInfo {
        $info = Get-JaxDiagnosticInfo -RuntimeRoot $PSScriptRoot -RepoRoot $jaxRepoRoot
        Write-Host 'Jax diagnostics'
        foreach ($entry in $info.Display.GetEnumerator()) {
            Write-Host ('  {0}: {1}' -f $entry.Key, $entry.Value)
        }
        if ($info.Warnings.Count -gt 0) {
            Write-Host ''
            Write-Host 'Warnings:' -ForegroundColor Yellow
            foreach ($warning in $info.Warnings) {
                Write-Host "  - $warning" -ForegroundColor Yellow
            }
        }
    }

    function ConvertTo-JaxBoolValue {
        param([string] $Value)
        if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
        switch ($Value.ToLowerInvariant()) {
            { $_ -in @('on', 'true', '1', 'yes', 'y', 'enable', 'enabled') } { return $true }
            { $_ -in @('off', 'false', '0', 'no', 'n', 'disable', 'disabled') } { return $false }
            default { throw "Invalid boolean value '$Value'. Expected on|off|true|false." }
        }
    }

    if ($Command -eq 'vault') {
        # Plugin command dispatch
        # jax vault set -> Connect-JaxVault
        # jax vault status -> Get-JaxVaultStatus
        # jax vault reset -> Reset-JaxVault

        $subCmd = if ($CommandArgs.Count -gt 0) { $CommandArgs[0].ToLowerInvariant() } else { 'status' }
        $subArgs = if ($CommandArgs.Count -gt 1) { $CommandArgs[1..($CommandArgs.Count - 1)] } else { @() }
        # Defensive: avoid passing empty positional args into plugin commands (can bind to VaultToken etc.)
        $subArgs = @($subArgs | Where-Object { $_ -ne $null -and -not [string]::IsNullOrWhiteSpace([string]$_) })

        try {
            # Load core config
            $repoRoot = $jaxRepoRoot
            $config = Get-JaxConfig -RepoRoot $repoRoot @commonParams

            # Try standard plugin load in case user configured it
            Import-JaxPlugins -Config $config -RepoRoot $repoRoot @commonParams | Out-Null

            # Force load Vault plugin if not loaded (it might be disabled in config but we need it for these commands)
            $vaultPluginPath = Get-JaxBuiltinPluginPath -Name 'vault'
            if (-not (Test-Path $vaultPluginPath)) {
                throw "Vault plugin not found at '$vaultPluginPath'"
            }

            Import-Module $vaultPluginPath -Global -Force -ErrorAction Stop


            switch ($subCmd) {
                'set' { Connect-JaxVault @commonParams @subArgs }
                'login' { Connect-JaxVault @commonParams @subArgs }
                'info' { Get-JaxVaultStatus @commonParams }
                'status' { Get-JaxVaultStatus @commonParams }
                'reset' { Reset-JaxVault @commonParams }
                'help' {
                    Write-Host "Usage: jax vault [command]"
                    Write-Host "Commands:"
                    Write-Host "  set (or login)  Authenticate with Vault (interactive)"
                    Write-Host "  status (or info)  Check Vault connection status"
                    Write-Host "  reset           Clear local Vault token"
                    Write-Host ""
                    Write-Host "Run overrides:"
                    Write-Host "  -vaultTokenEnv <name>  Use token from the named env var for one run"
                    Write-Host "  -useEnvVaultToken     Use VAULT_TOKEN for one run"
                    Write-Host "  -vaultToken <token>   Use literal token for one run (shell history risk)"
                }
                default {
                    Write-Error "Unknown vault command '$subCmd'. Try 'jax vault help'."
                }
            }
        } catch {
            Write-Error "Failed to execute vault command: $_"
        }
        return
    }


    switch ($Command) {
        'help' { Show-JaxHelp }
        '-h' { Show-JaxHelp }
        '--help' { Show-JaxHelp }
        'init' {
            $params = @{}
            $params.RepoRoot = $jaxRepoRoot
            if ($PSBoundParameters.ContainsKey('client')) { $params.Client = $client }
            if ($PSBoundParameters.ContainsKey('env')) { $params.Env = $env }
            if ($CommandArgs) {
                for ($i = 0; $i -lt $CommandArgs.Count; $i++) {
                    $arg = [string]$CommandArgs[$i]
                    if ($arg -match '^-(FlowConfig|BossConfig)=(.+)$') { $params.FlowConfig = $Matches[2] }
                    if ($arg -in @('-FlowConfig', '-BossConfig') -and $i + 1 -lt $CommandArgs.Count) {
                        $i++
                        $params.FlowConfig = [string]$CommandArgs[$i]
                    }
                    if ($arg -eq '-IncludeBobfile') { $params.IncludeBobfile = $true }
                    if ($arg -eq '-IncludeJaxfile') { $params.IncludeJaxfile = $true }
                    if ($arg -eq '-Customize') { $params.Customize = $true }
                }
            }
            Invoke-JaxInit @params @commonParams
        }
        'info' { Show-JaxInfo }
        'skill' {
            $installer = Join-Path $PSScriptRoot 'Install-JaxSkill.ps1'
            & $installer -RepoRoot $jaxRepoRoot
        }
        # 'init-compat' {
        #     $params = @{}
        #     if ($CommandArgs) {
        #         foreach ($arg in $CommandArgs) {
        #             if ($arg -eq '-Force') { $params.Force = $true }
        #         }
        #     }
        #     $path = Invoke-JaxInitCompatConfig @params
        #     Write-Host "Compatibility config created: $path"
        # }
        # 'init-legacy' {
        #     $params = @{}
        #     if ($CommandArgs) {
        #         foreach ($arg in $CommandArgs) {
        #             if ($arg -eq '-Force') { $params.Force = $true }
        #         }
        #     }
        #     $path = Invoke-JaxInitCompatConfig @params
        #     Write-Host "Compatibility config created: $path"
        # }
        'list-tasks' {
            $repoRoot = $jaxRepoRoot
            $config = Get-JaxConfig -RepoRoot $repoRoot @commonParams
            Import-JaxPlugins -Config $config -RepoRoot $repoRoot @commonParams | Out-Null

            $envs = Get-JaxEnvironments -RepoRoot $repoRoot -Config $config @commonParams
            # Default to current environment if not specified via -Env (though list-tasks typically needs env context)
            $parsed = Resolve-JaxCliArgs -Args $CommandArgs @commonParams
            $options = $parsed.Values
            if ($PSBoundParameters.ContainsKey('env')) { $options['env'] = $PSBoundParameters['env'] }
            if ($PSBoundParameters.ContainsKey('client')) { $options['client'] = $PSBoundParameters['client'] }

            $selection = Resolve-JaxEnvSelection -Environments $envs -Env $options['env'] -Client $options['client'] @commonParams
            $selectedEnv = $selection.Environment
            if ($null -eq $selectedEnv) {
                Write-Host "No environment selected. Use -Env or set a default environment to list tasks."
                return
            }

            $skipEnvRoot = $false
            if ($selectedEnv.PSObject.Properties.Match('SkipEnvRoot').Count -gt 0 -and $selectedEnv.SkipEnvRoot) {
                $skipEnvRoot = $true
            }
            if ($selectedEnv.PSObject.Properties.Match('IsDummy').Count -gt 0 -and $selectedEnv.IsDummy) {
                $skipEnvRoot = $true
            }
            $isComputedEnv = $false
            if ($selectedEnv.PSObject.Properties.Match('IsComputed').Count -gt 0 -and $selectedEnv.IsComputed) {
                $isComputedEnv = $true
            }

            $flowOverride = $selection.FlowOverride
            if ([string]::IsNullOrWhiteSpace($flowOverride)) {
                $flowConfigEntry = Resolve-JaxSelectedFlowConfig -Environment $selectedEnv @commonParams
            } else {
                $flowConfigEntry = Resolve-JaxSelectedFlowConfig -Environment $selectedEnv -PreferredConfig $flowOverride @commonParams
            }

            $allowMissingFlowConfig = $skipEnvRoot -or $isComputedEnv
            if ($null -eq $flowConfigEntry -and -not $allowMissingFlowConfig) {
                Write-Host "No flow configs found for environment '$($selectedEnv.Name)'."
                return
            }

            $flowConfig = $null
            if ($null -ne $flowConfigEntry) {
                $flowConfig = Get-JaxFlowConfig -Paths $flowConfigEntry.ConfigPaths -ExpandVariables:$false @commonParams
            }

            $envDir = $null
            if ($null -ne $flowConfigEntry -and $flowConfigEntry.PSObject.Properties.Match('EnvDirPath').Count -gt 0) {
                $envDir = $flowConfigEntry.EnvDirPath
            } elseif ($selectedEnv.PSObject.Properties.Match('EnvDir').Count -gt 0) {
                $envDir = $selectedEnv.EnvDir
            }
            $context = @{
                RepoRoot             = $repoRoot
                EnvDir               = $envDir
                Config               = $config
                SuppressRunConfigLog = $true
                SkipEnvRoot          = $skipEnvRoot
            }

            $discoveredEntities = Get-JaxDiscoveredRunEntities -RepoRoot $repoRoot -EnvDir $envDir -Config $config -SkipEnvRoot:$skipEnvRoot @commonParams
            $context['DiscoveredEntities'] = $discoveredEntities
            $context['DiscoveredEntityIndex'] = New-JaxRunEntityIndex -Entities $discoveredEntities

            $entities = @()
            # Include default scenario tasks
            if ($null -ne $flowConfig) {
                $entities += Get-JaxScenarioRunEntities -FlowConfig $flowConfig -Scenario 'default' -Context $context -ProvenancePath $flowConfigEntry.ConfigPath -ErrorAction SilentlyContinue @commonParams
            }

            # Add discovered
            if ($discoveredEntities.Count -gt 0) {
                $entities += $discoveredEntities
            }

            $keys = Get-JaxRunEntityKeys -Entities $entities -IncludeAliases
            if ($keys.Count -eq 0) {
                Write-Host "No tasks found."
                return
            }
            $keys | Sort-Object | Format-Wide -AutoSize
        }
        'list-envs' {
            $repoRoot = $jaxRepoRoot
            $config = Get-JaxConfig -RepoRoot $repoRoot @commonParams
            $envs = Get-JaxEnvironments -RepoRoot $repoRoot -Config $config @commonParams
            if ($envs.Count -eq 0) {
                Write-Host "No environments found."
                return
            }
            $envs = @($envs | Sort-Object -Property Name -Unique)
            foreach ($environment in $envs) {
                $clientKey = ($environment.Name -split '/')[0]
                $clientIcon = Get-JaxAutocompleteIcon -Config $config -Type 'client' -Key $clientKey

                $configs = @()
                foreach ($cfg in @($environment.FlowConfigs)) {
                    if ($null -ne $cfg -and $cfg.PSObject.Properties.Match('Configuration').Count -gt 0) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$cfg.Configuration)) {
                            $configs += [string]$cfg.Configuration
                        }
                    }
                }
                $configs = @($configs | Sort-Object -Unique)
                $configsText = if ($configs.Count -gt 0) { $configs -join ',' } else { 'none' }

                $flowIcon = '⚙️'
                if ($configs.Count -gt 0) {
                    $flowIcon = Get-JaxAutocompleteIcon -Config $config -Type 'flow' -Key $configs[0]
                } else {
                    $fallbackKey = ($environment.Name -split '/')[-1]
                    $flowIcon = Get-JaxAutocompleteIcon -Config $config -Type 'flow' -Key $fallbackKey -DefaultIcon '⚙️'
                }

                if ($environment.Name -match '^build/') {
                    Write-Host ("{0} {1} {2} [{3}]" -f $clientIcon, $flowIcon, $environment.Name, $configsText)
                } else {
                    Write-Host ("{0} {1} {2} [{3}]" -f $flowIcon, $clientIcon, $environment.Name, $configsText)
                }
            }
        }
        'env' {
            # Dispatch subcommands for env management
            # Usage: jax env init
            $subCmd = if ($CommandArgs.Count -gt 0) { $CommandArgs[0] } else { 'help' }
            $subArgs = if ($CommandArgs.Count -gt 1) { $CommandArgs[1..($CommandArgs.Count - 1)] } else { @() }



            switch ($subCmd) {
                'init' {
                    # jax env init -> New-JaxEnvironment
                    $envParams = @{ RepoRoot = $jaxRepoRoot }
                    $positionNames = @('Name', 'Client', 'DefaultFlow', 'Template')
                    $positionIndex = 0
                    for ($i = 0; $i -lt $subArgs.Count; $i++) {
                        $arg = [string]$subArgs[$i]
                        if ($arg -match '^-?(Name|Client|DefaultFlow|Template)=(.*)$') {
                            $envParams[$Matches[1]] = $Matches[2]
                            continue
                        }
                        if ($arg -match '^-(Name|Client|DefaultFlow|Template)$') {
                            if ($i + 1 -ge $subArgs.Count) {
                                throw "Missing value for environment option '$arg'."
                            }
                            $i++
                            $envParams[$Matches[1]] = [string]$subArgs[$i]
                            continue
                        }
                        if ($positionIndex -ge $positionNames.Count) {
                            throw "Unexpected environment argument: $arg"
                        }
                        $envParams[$positionNames[$positionIndex]] = $arg
                        $positionIndex++
                    }
                    New-JaxEnvironment @envParams @commonParams
                }
                default {
                    Write-Host "Usage: jax env [command]"
                    Write-Host "Commands:"
                    Write-Host "  init    Initialize a new environment (interactive)"
                }
            }
        }
        'create-flavour' {
            $params = @{ RepoRoot = $jaxRepoRoot }
            if ($CommandArgs) {
                foreach ($arg in $CommandArgs) {
                    if ($arg -like '-Name=*') { $params.Name = $arg.Split('=')[1] }
                    if ($arg -like '-Description=*') { $params.Description = $arg.Split('=')[1] }
                    if ($arg -eq '-Force') { $params.Force = $true }
                }
            }
            $path = Invoke-JaxCreateFlavour @params @commonParams
            Write-Host "Created flavour file: $path"
        }
        'autocomplete' {
            $completionModule = Join-Path $PSScriptRoot 'Jax.Autocomplete.psm1'
            if (-not (Test-Path -Path $completionModule -PathType Leaf)) {
                Write-Host "Autocomplete module not found: $completionModule"
                return
            }
            Import-Module $completionModule -Force
            Write-Host "Jax autocomplete registered for this session."
        }
        'run' {
            $repoRoot = $jaxRepoRoot
            $config = Get-JaxConfig -RepoRoot $repoRoot @commonParams
            Import-JaxPlugins -Config $config -RepoRoot $repoRoot @commonParams | Out-Null

            $parsed = Resolve-JaxCliArgs -Args $CommandArgs @commonParams
            $options = $parsed.Values
            # Merge static core flags into options (static wins over CommandArgs parsing)
            if ($PSBoundParameters.ContainsKey('env')) { $options['env'] = $PSBoundParameters['env'] }
            if ($PSBoundParameters.ContainsKey('client')) { $options['client'] = $PSBoundParameters['client'] }
            if ($PSBoundParameters.ContainsKey('scenario')) { $options['scenario'] = $PSBoundParameters['scenario'] }
            if ($PSBoundParameters.ContainsKey('from')) { $options['from'] = $PSBoundParameters['from'] }
            if ($PSBoundParameters.ContainsKey('to')) { $options['to'] = $PSBoundParameters['to'] }
            if ($PSBoundParameters.ContainsKey('only')) { $options['only'] = $PSBoundParameters['only'] }
            if ($PSBoundParameters.ContainsKey('noBuild')) { $options['noBuild'] = [bool]$PSBoundParameters['noBuild'] }
            if ($PSBoundParameters.ContainsKey('buildChainOnly')) { $options['buildChainOnly'] = [bool]$PSBoundParameters['buildChainOnly'] }
            if ($PSBoundParameters.ContainsKey('noCache')) { $options['noCache'] = [bool]$PSBoundParameters['noCache'] }
            if ($PSBoundParameters.ContainsKey('Quiet')) { $options['quiet'] = [bool]$PSBoundParameters['Quiet'] }
            if ($PSBoundParameters.ContainsKey('NoQuiet')) { $options['noQuiet'] = [bool]$PSBoundParameters['NoQuiet'] }
            # Common parameters (-Verbose/-Debug) are bound by PowerShell and do NOT appear in CommandArgs parsing,
            # but we still want them to influence Jax's internal preference/diagnostic behavior.
        if ($PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose']) { $options['verbose'] = $true }
        if ($PSBoundParameters.ContainsKey('Debug') -and $PSBoundParameters['Debug']) { $options['debug'] = $true }

        # IMPORTANT:
        # DynamicParam now exposes plugin-defined CLI flags as native PowerShell parameters.
        # That means flags like -novault/-onlyLocalArch may NOT appear in $CommandArgs anymore,
        # so Resolve-JaxCliArgs won't see them. Merge known CLI params from PSBoundParameters.
        try {
            $cliDefs = @(Get-JaxCliParameters)
            $cliSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($d in $cliDefs) {
                if ($null -eq $d) { continue }
                if ($d.Name) { $cliSet.Add([string]$d.Name) | Out-Null }
            }
            foreach ($k in @($PSBoundParameters.Keys)) {
                if ($cliSet.Contains([string]$k)) {
                    $def = $cliDefs | Where-Object { $_.Name -ieq $k } | Select-Object -First 1
                    if ($def -and $def.Type -eq 'switch') {
                        $options[[string]$k] = [bool]$PSBoundParameters[$k]
                    } else {
                        $options[[string]$k] = $PSBoundParameters[$k]
                    }
                }
            }
        } catch {
            # best effort
        }
        if ($parsed.Remaining.Count -gt 0 -and [string]::IsNullOrWhiteSpace($options['only'])) {
            $options['only'] = $parsed.Remaining[0]
        }
        # Also capture any unknown flags (including dynamic/extra args) so they can still override defaults.
        # CLI `-myData X` should override `args.myData` even if DynamicParam
        # couldn't materialize `-myData` as a bound parameter.
        $unknownCliArgs = Convert-JaxCliUnknownToHashtable -Unknown $parsed.Unknown

        if ($options.ContainsKey('forceReloadModules') -and $options.forceReloadModules) {
            Write-Verbose "--------------------------------"
            Write-Verbose "ForceReloadModules: Force reloading Jax modules"
            Write-Verbose "--------------------------------"
            Write-Verbose "Importing Jax core module"
            try {
                Import-Module $coreModulePath -Global -Force -ErrorAction Stop
            } catch {
                throw "Failed to re-import Jax core module '$coreModulePath' (force reload): $($_.Exception.Message)"
            }
            Write-Verbose "ForceReloadModules: Reloading Jax modules"

            Invoke-JaxModulesReload -RepoRoot $repoRoot -ExcludeModuleNames @('Jax.Core.psm1') -Config $config @commonParams
            # Reload can unload other Jax modules/plugins; re-import core to ensure exported functions are available.
            try {
                Import-Module $coreModulePath -Global -Force -ErrorAction Stop
            } catch {
                throw "Failed to import Jax core module '$coreModulePath' after module reload: $($_.Exception.Message)"
            }
            Write-Verbose "ForceReloadModules: Importing Jax plugins"

            Import-JaxPlugins -Config $config -RepoRoot $repoRoot @commonParams | Out-Null
        }

        if ($options.ContainsKey('dv') -and $options.dv) {
            $DebugPreference = 'Continue'
            $VerbosePreference = 'Continue'
        } else {
            if ($options.ContainsKey('debug') -and $options.debug) {
                $DebugPreference = 'Continue'
            }
            if ($options.ContainsKey('verbose') -and $options.verbose) {
                $VerbosePreference = 'Continue'
            }
        }

        if ($options.ContainsKey('clearOutput') -and $options.clearOutput) {
            Clear-Host
        }

        $noSavedSettings = $options.ContainsKey('noSavedSettings') -and $options.noSavedSettings
        # Shortcuts are self-contained (-env/-only in the saved args); do not persist env/client/scenario
        # to .jax/state.yml or we overwrite the user's "last explicit" context for the next normal run.
        if (-not [string]::IsNullOrWhiteSpace($Shortcut)) {
            $noSavedSettings = $true
        }
        $state = Get-JaxState -RepoRoot $repoRoot -NoSavedSettings:$noSavedSettings @commonParams
        $stateCore = @{}
        if ($state -is [System.Collections.IDictionary] -and $state.Contains('core') -and $state['core'] -is [System.Collections.IDictionary]) {
            $stateCore = $state['core']
        }
        $resolved = Merge-JaxHashtable -Base $stateCore -Overlay $options

        # Ensure explicitly passed static core flags always win (even if state/options merging gets weird).
        if ($PSBoundParameters.ContainsKey('env')) { $resolved['env'] = $PSBoundParameters['env'] }
        if ($PSBoundParameters.ContainsKey('client')) { $resolved['client'] = $PSBoundParameters['client'] }
        if ($PSBoundParameters.ContainsKey('scenario')) { $resolved['scenario'] = $PSBoundParameters['scenario'] }
        if ($PSBoundParameters.ContainsKey('from')) { $resolved['from'] = $PSBoundParameters['from'] }
        if ($PSBoundParameters.ContainsKey('to')) { $resolved['to'] = $PSBoundParameters['to'] }
        if ($PSBoundParameters.ContainsKey('only')) { $resolved['only'] = $PSBoundParameters['only'] }
        if ($PSBoundParameters.ContainsKey('noBuild')) { $resolved['noBuild'] = [bool]$PSBoundParameters['noBuild'] }
        if ($PSBoundParameters.ContainsKey('buildChainOnly')) { $resolved['buildChainOnly'] = [bool]$PSBoundParameters['buildChainOnly'] }
        if ($PSBoundParameters.ContainsKey('noCache')) { $resolved['noCache'] = [bool]$PSBoundParameters['noCache'] }
        if ($PSBoundParameters.ContainsKey('Quiet')) { $resolved['quiet'] = [bool]$PSBoundParameters['Quiet'] }
        if ($PSBoundParameters.ContainsKey('NoQuiet')) { $resolved['noQuiet'] = [bool]$PSBoundParameters['NoQuiet'] }

        # Quiet mode is computed once and propagated through the run context so that all
        # output sites (run header, entity banner, plan log breadcrumb) gate uniformly.
        $quietMode = Test-JaxQuietMode -Resolved $resolved

        # Cross-process signal: child psake/scripts and devops/ps wrappers (Test-JaxQuietContext)
        # honor $env:JAX_QUIET. Scoped to the current jax.ps1 process — does not leak between runs.
        if ($quietMode) { $env:JAX_QUIET = '1' } else { Remove-Item Env:JAX_QUIET -ErrorAction SilentlyContinue }

        # NOTE: we intentionally do NOT persist from/to/only in state (see Update-JaxState).

        $envs = Get-JaxEnvironments -RepoRoot $repoRoot -Config $config @commonParams
        if ($envs.Count -eq 0) {
            Write-Host "No environments found."
            return
        }

        $selection = Resolve-JaxEnvSelection -Environments $envs -Env $resolved['env'] -Client $resolved['client'] @commonParams
        $selectedEnv = $selection.Environment
        $flowOverride = $selection.FlowOverride
        if ($resolved.ContainsKey('printCurrentEnv') -and [bool]$resolved.printCurrentEnv) {
            Write-Host $selectedEnv.Name
            return
        }

        $skipEnvRoot = $false
        if ($selectedEnv.PSObject.Properties.Match('SkipEnvRoot').Count -gt 0 -and $selectedEnv.SkipEnvRoot) {
            $skipEnvRoot = $true
        }
        if ($selectedEnv.PSObject.Properties.Match('IsDummy').Count -gt 0 -and $selectedEnv.IsDummy) {
            $skipEnvRoot = $true
        }
        $isComputedEnv = $false
        if ($selectedEnv.PSObject.Properties.Match('IsComputed').Count -gt 0 -and $selectedEnv.IsComputed) {
            $isComputedEnv = $true
        }

        if ([string]::IsNullOrWhiteSpace($flowOverride)) {
            $flowConfigEntry = Resolve-JaxSelectedFlowConfig -Environment $selectedEnv @commonParams
        } else {
            $flowConfigEntry = Resolve-JaxSelectedFlowConfig -Environment $selectedEnv -PreferredConfig $flowOverride @commonParams
        }
        $allowMissingFlowConfig = $skipEnvRoot -or $isComputedEnv
        if ($null -eq $flowConfigEntry -and -not $allowMissingFlowConfig) {
            Write-Host "No flow configs found for environment '$($selectedEnv.Name)'."
            return
        }

        $flowConfig = $null
        if ($null -ne $flowConfigEntry) {
            $flowConfig = Get-JaxFlowConfig -Paths $flowConfigEntry.ConfigPaths -ExpandVariables:$false @commonParams
        }

        $envDir = $null
        if ($null -ne $flowConfigEntry -and $flowConfigEntry.PSObject.Properties.Match('EnvDirPath').Count -gt 0) {
            $envDir = $flowConfigEntry.EnvDirPath
        } elseif ($selectedEnv.PSObject.Properties.Match('EnvDir').Count -gt 0) {
            $envDir = $selectedEnv.EnvDir
        }

        $context = @{
            RepoRoot    = $repoRoot
            EnvDir      = $envDir
            Config      = $config
            SkipEnvRoot = $skipEnvRoot
            Quiet       = $quietMode
        }
        if ($quietMode) {
            # Honored by Invoke-JaxRunEntity to skip the framed entity banner.
            $context['SuppressEntityBanner'] = $true
        }
        $context['CommonParameters'] = $commonParams
        # Used by runners to resolve relative paths (scripts/psakefile) against the env folder.
        if (-not [string]::IsNullOrWhiteSpace($envDir)) {
            $context['WorkingDir'] = $envDir
        } else {
            $context['WorkingDir'] = $repoRoot
        }
        if ($null -ne $flowConfigEntry -and $flowConfigEntry.PSObject.Properties.Match('EnvDirPath').Count -gt 0) {
            $defaultPsakeFile = Join-Path $flowConfigEntry.EnvDirPath 'psakefile.ps1'
            if (Test-Path -LiteralPath $defaultPsakeFile -PathType Leaf) {
                $context['PsakeFile'] = $defaultPsakeFile
            }
        }
        if ($options.ContainsKey('debug') -and $options.debug) { $context['Debug'] = $true }
        if ($options.ContainsKey('verbose') -and $options.verbose) { $context['Verbose'] = $true }
        # Make state/options available to plugins (so they can implement persisted preferences without jax.ps1 hardcoding).
        $context['State'] = $state
        $context['NoSavedSettings'] = $noSavedSettings
        $context['SelectedEnv'] = $selectedEnv
        $context['FlowConfigEntry'] = $flowConfigEntry
        $context['ResolvedOptions'] = $resolved
        # Allow plugins to adjust header state (and update persisted settings) before we render the header.
        Invoke-JaxHooks -Name 'BeforeRunHeader' -Context $context -Data @{
            SelectedEnv     = $selectedEnv
            FlowConfigEntry = $flowConfigEntry
            Resolved        = $resolved
        } @commonParams
        $headerFlowConfig = if ($null -ne $flowConfigEntry) { $flowConfigEntry } else { [pscustomobject]@{} }
        if (-not $quietMode) {
            Write-JaxRunHeader -RepoRoot $repoRoot -SelectedEnv $selectedEnv -FlowConfigEntry $headerFlowConfig -Config $config -Resolved $resolved
        } else {
            $envName = if ($selectedEnv -and $selectedEnv.PSObject.Properties.Match('Name').Count -gt 0) { [string]$selectedEnv.Name } else { '' }
            if (-not [string]::IsNullOrWhiteSpace($envName)) {
                Write-Host ("jax: env={0}" -f $envName)
            }
        }
        Invoke-JaxHooks -Name 'RunHeader' -Context $context -Data @{
            SelectedEnv     = $selectedEnv
            FlowConfigEntry = $flowConfigEntry
            Resolved        = $resolved
        } @commonParams
        # Forward any additional DynamicParam-bound task/script parameters into the run context.
        # Runners will merge these into their args/properties (CLI overrides win).
        $reservedKeys = @(
            'Command', 'CommandArgs', 'env', 'client', 'scenario', 'from', 'to', 'only', 'noBuild', 'buildChainOnly', 'noCache',
            'Detailed', 'Shortcut', 'SaveShortcut', 'RemoveShortcut', 'vault', 'novault', 'vaultToken', 'vaultTokenEnv', 'useEnvVaultToken',
            'coverage', 'nocoverage'
        )
        $reservedLower = @($reservedKeys | ForEach-Object { $_.ToLowerInvariant() })
        $commonKeys = @((Get-JaxCommonParameters -BoundParameters $PSBoundParameters).Keys | ForEach-Object { $_.ToLowerInvariant() })
        $cliArgs = @{}
        foreach ($k in @($PSBoundParameters.Keys)) {
            if ([string]::IsNullOrWhiteSpace($k)) { continue }
            $lk = $k.ToLowerInvariant()
            if ($reservedLower -contains $lk) { continue }
            if ($commonKeys -contains $lk) { continue }
            $cliArgs[$k] = $PSBoundParameters[$k]
        }
        # Unknown CLI args (from CommandArgs parsing) are lower precedence than actual bound parameters.
        if ($null -ne $unknownCliArgs -and $unknownCliArgs.Count -gt 0) {
            $cliKnown = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($def in Get-JaxCliParameters) {
                if ($def -and $def.Name) {
                    $cliKnown.Add([string]$def.Name) | Out-Null
                }
                foreach ($a in @($def.Aliases)) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$a)) {
                        $cliKnown.Add([string]$a) | Out-Null
                    }
                }
            }
            foreach ($k in @($unknownCliArgs.Keys)) {
                if ([string]::IsNullOrWhiteSpace([string]$k)) { continue }
                $lk = ([string]$k).ToLowerInvariant()
                if ($reservedLower -contains $lk) { continue }
                if ($commonKeys -contains $lk) { continue }
                if ($cliKnown.Contains([string]$k)) { continue }
                if (-not $cliArgs.ContainsKey([string]$k)) {
                    $cliArgs[[string]$k] = $unknownCliArgs[$k]
                }
            }
        }
        if ($cliArgs.Count -gt 0) {
            $context['CliArgs'] = $cliArgs
        }
        if ($resolved.ContainsKey('noCache') -and $resolved.noCache) {
            $context['NoCache'] = $true
        }
        $overrideList = @()
        if ($resolved.ContainsKey('override')) {
            $overrideList += Convert-JaxCliListValue -Value $resolved.override
        }
        if ($resolved.ContainsKey('overrides')) {
            $overrideList += Convert-JaxCliListValue -Value $resolved.overrides
        }
        if ($overrideList.Count -gt 0) {
            $context['Overrides'] = @($overrideList | Sort-Object -Unique)
        }

        $noTasksDiscovery = $resolved.ContainsKey('noTasksDiscovery') -and [bool]$resolved['noTasksDiscovery']
        $noScriptsDiscovery = $resolved.ContainsKey('noScriptsDiscovery') -and [bool]$resolved['noScriptsDiscovery']
        $noScenarioDiscovery = $resolved.ContainsKey('noScenarioDiscovery') -and [bool]$resolved['noScenarioDiscovery']
        $noCache = $resolved.ContainsKey('noCache') -and [bool]$resolved['noCache']

        $discoveredEntities = @()
        if (-not $noTasksDiscovery -or -not $noScriptsDiscovery) {
            $discoveredEntities = Get-JaxDiscoveredRunEntities -RepoRoot $repoRoot -EnvDir $envDir -Config $config -NoTasksDiscovery:$noTasksDiscovery -NoScriptsDiscovery:$noScriptsDiscovery -NoCache:$noCache -SkipEnvRoot:$skipEnvRoot @commonParams
            $context['DiscoveredEntities'] = $discoveredEntities
            $context['DiscoveredEntityIndex'] = New-JaxRunEntityIndex -Entities $discoveredEntities
        }

        if ([bool]$resolved['listScenarios']) {
            if ($null -eq $flowConfig) {
                Write-Host "No scenarios found."
                return
            }
            $names = Get-JaxScenarioNames -FlowConfig $flowConfig @commonParams
            if ($names.Count -eq 0) {
                Write-Host "No scenarios found."
                return
            }
            $names | Format-Wide -AutoSize
            return
        }

        if ([bool]$resolved['listTasks']) {
            $entities = @()
            if ($null -ne $flowConfig -and -not $noScenarioDiscovery -and -not $noTasksDiscovery) {
                $entities += Get-JaxScenarioRunEntities -FlowConfig $flowConfig -Scenario $resolved['scenario'] -Context $context -ProvenancePath $flowConfigEntry.ConfigPath @commonParams
            }
            if ($discoveredEntities.Count -gt 0) {
                $entities += $discoveredEntities
            }
            $keys = Get-JaxRunEntityKeys -Entities $entities -IncludeAliases @commonParams
            if ($keys.Count -eq 0) {
                Write-Host "No tasks found."
                return
            }
            $keys | Format-Wide -AutoSize
            return
        }

        $scenarioEntities = @()
        if ($null -ne $flowConfig -and -not $noScenarioDiscovery -and -not $noTasksDiscovery) {
            $scenarioEntities = Get-JaxScenarioRunEntities -FlowConfig $flowConfig -Scenario $resolved['scenario'] -Context $context -ProvenancePath $flowConfigEntry.ConfigPath @commonParams
        }
        $context['ScenarioEntityIndex'] = New-JaxRunEntityIndex -Entities $scenarioEntities
        if ($noScriptsDiscovery) {
            $scenarioEntities = @($scenarioEntities | Where-Object { -not (Test-JaxRunEntityIsScript -Entity $_) })
        }

        $buildEntities = @()
        if ($null -ne $flowConfig) {
            $buildEntities = Get-JaxBuildRunEntities -FlowConfig $flowConfig -Config $config -Context $context -ProvenancePath $flowConfigEntry.ConfigPath @commonParams
        }

        # Ensure run-config is available even when there is no flow config (dummy env or scenario discovery disabled).
        $skipScenarioResolution = ($null -eq $flowConfig) -or $noScenarioDiscovery -or $noTasksDiscovery
        if ($skipScenarioResolution -and -not ($context.ContainsKey('RunConfig'))) {
            if (-not ($context.ContainsKey('CommonParameters'))) {
                $context['CommonParameters'] = $commonParams
            }
            Invoke-JaxHooks -Name 'BeforeSequenceResolve' -Context $context -Data @{
                FlowConfig     = $flowConfig
                Scenario       = $resolved['scenario']
                FlowConfigPath = if ($flowConfigEntry) { $flowConfigEntry.ConfigPath } else { $null }
            }
        }

        $resolvedOnly = $resolved['only']
        $plan = Resolve-JaxRunPlan `
            -BuildEntities $buildEntities `
            -ScenarioEntities $scenarioEntities `
            -IndividualEntities $discoveredEntities `
            -NoBuild:([bool]$resolved['noBuild']) `
            -BuildChainOnly:([bool]$resolved['buildChainOnly']) `
            -Only $resolvedOnly `
            -From ([string]$resolved['from']) `
            -To ([string]$resolved['to']) `
            -Context $context @commonParams

        $hasNoPlan = ($null -eq $plan) -or ($plan.Count -eq 0)
        if ($hasNoPlan) {
            $selectorOnly = [string]$resolved['only']
            $selectorFrom = [string]$resolved['from']
            $selectorTo = [string]$resolved['to']
            $selectorEnv = [string]$resolved['env']
            $selectorScenario = [string]$resolved['scenario']

            $selectorsSummary = @()
            if (-not [string]::IsNullOrWhiteSpace($selectorOnly)) { $selectorsSummary += "-only '$selectorOnly'" }
            if (-not [string]::IsNullOrWhiteSpace($selectorFrom)) { $selectorsSummary += "-from '$selectorFrom'" }
            if (-not [string]::IsNullOrWhiteSpace($selectorTo)) { $selectorsSummary += "-to '$selectorTo'" }
            if (-not [string]::IsNullOrWhiteSpace($selectorScenario)) { $selectorsSummary += "-scenario '$selectorScenario'" }
            $selectorsText = if ($selectorsSummary.Count -gt 0) { ($selectorsSummary -join ', ') } else { '(none)' }

            $hint = @()
            if ([string]::IsNullOrWhiteSpace($selectorOnly) -and -not [string]::IsNullOrWhiteSpace($selectorTo) -and [string]::IsNullOrWhiteSpace($selectorFrom)) {
                $hint += "It looks like you used -to without -from. Note: '-t' is an alias for '-to' (build-chain slicing), not 'task'."
                $hint += "If you meant to run a single task/entity, use: -only '$selectorTo' (or -o '$selectorTo')."
                $hint += "If you meant a build chain slice, use: -from <StartKey> -to '$selectorTo'."
            }
            $hint += "To see available tasks: jax -e $selectorEnv listTasks"
            $hint += "To preview what would run: jax -e $selectorEnv plan -only <TaskKey>"

            $hintText = ($hint | Where-Object { $_ } | ForEach-Object { "  - $_" }) -join "`n"
            throw @"
No run entities matched your selection.

Env: $selectorEnv
Selectors: $selectorsText

Hints:
$hintText
"@
        }
        if ([bool]$resolved['docker'] -or [bool]$resolved['container']) {
            $runConfig = $null
            if ($context.ContainsKey('RunConfig')) {
                $runConfig = $context['RunConfig']
            }
            $defaultImage = Resolve-JaxDefaultContainerImage -RunConfig $runConfig
            if ([string]::IsNullOrWhiteSpace($defaultImage)) {
                Write-Host "⚠️  -docker requested but no container image was found in run-config."
            } else {
                $plan = Set-JaxContainerOverride -Entities $plan -Image $defaultImage
                $context['DefaultContainerImage'] = $defaultImage
            }
        }
        $planLog = $null
        if ($plan.Count -gt 0) {
            $planLog = Write-JaxPlanLog -Entities $plan -RepoRoot $repoRoot @commonParams
            if (-not $quietMode) {
                Write-Host ("🪵 → 📋 Run plan saved: {0}" -f (Format-JaxPathLink -Path $planLog @commonParams))
            }
        }

        # Real execution (or dry-run/plan variants). We wrap in try/finally so that
        # even on exceptions, Ctrl-C, or psake crashes we reliably restore any terminal
        # / cmux surface titles we changed (e.g. "WTW Shell" or other wtw-named tabs).
        try {
            if ($options.ContainsKey('dryRunDeep') -and $options.dryRunDeep) {
                $plan | ConvertTo-Json -Depth 6
            } elseif ($options.ContainsKey('plan') -and $options.plan) {
                Write-JaxPlanOutput -Entities $plan -Detailed:$Detailed -Context $context @commonParams
            } elseif ($options.ContainsKey('dryRun') -and $options.dryRun) {
                $plan | Format-List
            } else {
                $context['SuppressResults'] = $true
                Invoke-JaxRunEntities -Entities $plan -Context $context @commonParams
            }
        }
        finally {
            try {
                Complete-JaxTerminalTitle
            } catch {
                # Never let title finalization break anything on exit
            }
        }

        if (-not $noSavedSettings) {
            $coreUpdate = @{
                env      = $resolved['env']
                client   = $resolved['client']
                scenario = $resolved['scenario']
            }
            # IMPORTANT: never persist from/to/only. Those are execution selectors and
            # must remain ephemeral to avoid "stale slicing" surprises across runs.
            # Plugins may persist their own settings under their own namespace if needed
            # (e.g. plugins.bob.vault=true, plugins.test.enabled=true).
            Update-JaxState -RepoRoot $repoRoot -Updates @{ core = $coreUpdate } @commonParams | Out-Null
        }

        if ($options.ContainsKey('beep') -and $options.beep) {
            Invoke-JaxBeep
        }
        }
        'settings' {
            $action = if ($CommandArgs -and $CommandArgs.Count -gt 0) { $CommandArgs[0] } else { $null }
            switch ($action) {
                'reset' {
                    Reset-JaxState -RepoRoot $jaxRepoRoot @commonParams
                    Write-Host "Jax settings reset."
                }
                'show' {
                    $repoRoot = $jaxRepoRoot
                    $state = Get-JaxState -RepoRoot $repoRoot @commonParams
                    if ($null -ne $state) {
                        $state | ConvertTo-Json -Depth 6
                    }
                }
                'set' {
                    if ($CommandArgs.Count -lt 2) {
                        Write-Host "Usage: jax settings set <key> [<value>]"
                        Show-JaxSettingsHelp
                        return
                    }
                    $key = [string]$CommandArgs[1]
                    $rawValue = if ($CommandArgs.Count -ge 3) { [string]$CommandArgs[2] } else { 'on' }
                    $repoRoot = $jaxRepoRoot
                    $boolKeys = @('quiet', 'verbose', 'docker', 'container', 'dryRun')
                    if ($boolKeys -contains $key) {
                        $val = ConvertTo-JaxBoolValue -Value $rawValue
                        Update-JaxState -RepoRoot $repoRoot -Updates @{ core = @{ $key = $val } } @commonParams | Out-Null
                        Write-Host ("ok: core.{0}={1}" -f $key, $val)
                    } else {
                        # Generic string setter under core.<key>.
                        Update-JaxState -RepoRoot $repoRoot -Updates @{ core = @{ $key = $rawValue } } @commonParams | Out-Null
                        Write-Host ("ok: core.{0}={1}" -f $key, $rawValue)
                    }
                }
                default {
                    Show-JaxSettingsHelp
                }
            }
        }
        default {
            Show-JaxHelp
        }
    }
}
