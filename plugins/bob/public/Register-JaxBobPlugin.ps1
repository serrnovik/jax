function Register-JaxBobPlugin {
    $hooks = @{
        BeforeSequenceResolve = {
            param($hook)
            $context = $hook.Context
            $pluginConfig = Get-JaxBobPluginConfig -PluginConfig $hook.PluginConfig
            $commonParams = @{}
            if ($context.ContainsKey('CommonParameters') -and $context['CommonParameters'] -is [System.Collections.IDictionary]) {
                $commonParams = $context['CommonParameters']
            }
            Write-Debug ("[bob] BeforeSequenceResolve start RepoRoot='{0}' EnvDir='{1}'" -f $context['RepoRoot'], $context['EnvDir'])
            $repoRoot = $context['RepoRoot']
            if ([string]::IsNullOrWhiteSpace($repoRoot)) {
                $repoRoot = Get-JaxRepoRoot
                $context['RepoRoot'] = $repoRoot
            }

            $selectedEnvName = $null
            $selectedClient = $null
            $selectedEnvType = $null
            if ($context.ContainsKey('SelectedEnv') -and $null -ne $context['SelectedEnv']) {
                $sel = $context['SelectedEnv']
                if ($sel.PSObject.Properties.Match('Name').Count -gt 0) {
                    $selectedEnvName = [string]$sel.Name
                }
            }
            if ([string]::IsNullOrWhiteSpace($selectedEnvName) -and $context.ContainsKey('ResolvedOptions') -and $context['ResolvedOptions'] -is [System.Collections.IDictionary]) {
                $opts = $context['ResolvedOptions']
                if ($opts.ContainsKey('env')) { $selectedEnvName = [string]$opts['env'] }
                if ($opts.ContainsKey('client')) { $selectedClient = [string]$opts['client'] }
            }
            if (-not [string]::IsNullOrWhiteSpace($selectedEnvName) -and $selectedEnvName.Contains('/')) {
                $parts = $selectedEnvName -split '/'
                if ($parts.Count -gt 1) {
                    $selectedClient = $parts[0]
                    $selectedEnvType = $parts[-1]
                }
            } elseif (-not [string]::IsNullOrWhiteSpace($selectedEnvName)) {
                $selectedEnvType = $selectedEnvName
            }
            $suiteEnv = $null
            if (-not [string]::IsNullOrWhiteSpace($selectedClient) -and -not [string]::IsNullOrWhiteSpace($selectedEnvType)) {
                $suiteEnv = "{0}/{1}" -f $selectedClient, $selectedEnvType
            } elseif (-not [string]::IsNullOrWhiteSpace($selectedEnvName)) {
                $suiteEnv = $selectedEnvName
            } elseif (-not [string]::IsNullOrWhiteSpace($selectedClient)) {
                $suiteEnv = $selectedClient
            }

            # Worktree isolation: only inject env.worktree when -worktreeIsolation flag is passed
            $worktreeIsolationEnabled = $false
            if ($context.ContainsKey('ResolvedOptions') -and $context['ResolvedOptions'] -is [System.Collections.IDictionary]) {
                $resolvedOpts = $context['ResolvedOptions']
                if ($resolvedOpts.Contains('worktreeIsolation') -and [bool]$resolvedOpts['worktreeIsolation']) {
                    $worktreeIsolationEnabled = $true
                }
            }

            $worktreeBlock = @{
                id              = ''
                index           = 0
                port_offset     = 0
                dashed_postfix  = ''
                active          = $false
            }
            if ($worktreeIsolationEnabled) {
                $wtId = $env:DEV_WORKTREE_ID ?? ''
                if (-not [string]::IsNullOrEmpty($wtId)) {
                    $worktreeBlock = @{
                        id              = $wtId
                        index           = [int]($env:DEV_WORKTREE_INDEX ?? '0')
                        port_offset     = [int]($env:DEV_WORKTREE_PORT_OFFSET ?? '0')
                        dashed_postfix  = $env:DEV_WORKTREE_DASHED_POSTFIX ?? ''
                        active          = $true
                    }
                    Write-Host "  Worktree isolation: ON (id=$wtId, offset=$($worktreeBlock.port_offset))" -ForegroundColor DarkCyan
                } else {
                    Write-Verbose "Worktree isolation flag set but no DEV_WORKTREE_ID in environment — running in shared mode."
                }
            }

            $baseVars = @{
                env  = @{
                    git   = @{
                        root = $repoRoot
                    }
                    build = @{
                        counter = 0
                    }
                    worktree = $worktreeBlock
                }
                boss = @{
                    suite = @{
                        name     = $suiteEnv
                        client   = $selectedClient
                        env_type = $selectedEnvType
                        env      = $suiteEnv
                        version  = @{
                            base   = '0.0.0'
                            number = '0.0.0'
                        }
                    }
                }
                flow = @{
                    suite = @{
                        name     = $suiteEnv
                        client   = $selectedClient
                        env_type = $selectedEnvType
                        env      = $suiteEnv
                        version  = @{
                            base   = '0.0.0'
                            number = '0.0.0'
                        }
                    }
                }
            }
            $existingVarsOverride = @{}
            if ($context.ContainsKey('VariablesOverride') -and $context['VariablesOverride'] -is [System.Collections.IDictionary]) {
                $existingVarsOverride = $context['VariablesOverride']
            }
            $context['VariablesOverride'] = Merge-JaxHashtable -Base $baseVars -Overlay $existingVarsOverride @commonParams

            $flowConfig = $null
            if ($hook.Data -and $hook.Data.ContainsKey('FlowConfig')) {
                $flowConfig = $hook.Data['FlowConfig']
            }
            if ($flowConfig -is [System.Collections.IDictionary] -and $flowConfig.Contains('suite') -and $flowConfig['suite'] -is [System.Collections.IDictionary]) {
                $suite = $flowConfig['suite']
                $suiteClient = if ($suite.Contains('client')) { $suite['client'] } else { $null }
                $suiteEnvType = if ($suite.Contains('env_type')) { $suite['env_type'] } else { $null }
                $suiteName = if ($suite.Contains('name')) { $suite['name'] } else { $null }

                $suiteEnv = $null
                if ($suite.Contains('env')) {
                    $suiteEnv = $suite['env']
                }
                if ($suiteEnv -is [string]) {
                    if (-not [string]::IsNullOrWhiteSpace($suiteClient)) {
                        $suiteEnv = $suiteEnv -replace '\{\{\s*boss\.suite\.client\s*\}\}', [string]$suiteClient
                    }
                    if (-not [string]::IsNullOrWhiteSpace($suiteEnvType)) {
                        $suiteEnv = $suiteEnv -replace '\{\{\s*boss\.suite\.env_type\s*\}\}', [string]$suiteEnvType
                    }
                }
                if ([string]::IsNullOrWhiteSpace($suiteEnv)) {
                    if (-not [string]::IsNullOrWhiteSpace($suiteClient) -and -not [string]::IsNullOrWhiteSpace($suiteEnvType)) {
                        $suiteEnv = "{0}/{1}" -f $suiteClient, $suiteEnvType
                    } else {
                        $suiteEnv = $suiteClient
                    }
                }

                $suiteVersion = $null
                if ($suite.Contains('version') -and $suite['version'] -is [System.Collections.IDictionary]) {
                    $suiteVersion = $suite['version']
                }

                # "boss" is the legacy naming for the flow domain. We keep boss.suite.* for
                # backward compatibility with bob/jaxfile templates, and also provide a
                # neutral alias under flow.suite.*.
                $suiteVars = @{
                    suite = @{}
                }
                if (-not [string]::IsNullOrWhiteSpace([string]$suiteName)) {
                    $suiteVars.suite['name'] = $suiteName
                }
                if (-not [string]::IsNullOrWhiteSpace([string]$suiteClient)) {
                    $suiteVars.suite['client'] = $suiteClient
                }
                if (-not [string]::IsNullOrWhiteSpace([string]$suiteEnvType)) {
                    $suiteVars.suite['env_type'] = $suiteEnvType
                }
                if (-not [string]::IsNullOrWhiteSpace([string]$suiteEnv)) {
                    $suiteVars.suite['env'] = $suiteEnv
                }
                if ($null -ne $suiteVersion) {
                    $suiteVars.suite['version'] = $suiteVersion
                }
                $varsFlow = @{
                    boss = $suiteVars
                    flow = $suiteVars
                }

                $existingVarsOverride = @{}
                if ($context.ContainsKey('VariablesOverride') -and $context['VariablesOverride'] -is [System.Collections.IDictionary]) {
                    $existingVarsOverride = $context['VariablesOverride']
                }
                $context['VariablesOverride'] = Merge-JaxHashtable -Base $varsFlow -Overlay $existingVarsOverride @commonParams
                Write-Debug ("[bob] VariablesOverride populated: boss.suite.env='{0}' (flow alias also set)" -f $suiteEnv)
            }

            if ($pluginConfig.Contains('git') -and $pluginConfig['git'] -is [System.Collections.IDictionary]) {
                $gitSettings = $pluginConfig['git']
                if (-not ($gitSettings.Contains('require') -and -not [bool]$gitSettings['require'])) {
                    $inputQueue = $null
                    if ($context.ContainsKey('InputQueue')) {
                        $inputQueue = $context['InputQueue']
                    }
                    $repoRoot = Initialize-JaxBobGitReady -RepoRoot $repoRoot -PluginConfig $pluginConfig -InputQueue $inputQueue
                    $context['RepoRoot'] = $repoRoot
                }
            }

            $envDir = $null
            if ($context.ContainsKey('EnvDir')) {
                $envDir = $context['EnvDir']
            }
            if ([string]::IsNullOrWhiteSpace($envDir)) {
                $flowConfigPath = $null
                if ($hook.Data -and $hook.Data.ContainsKey('FlowConfigPath')) {
                    $flowConfigPath = $hook.Data['FlowConfigPath']
                }
                $envDir = Resolve-JaxEnvDirFromFlowPath -FlowConfigPath $flowConfigPath -Config $hook.Config -RepoRoot $repoRoot
                if (-not [string]::IsNullOrWhiteSpace($envDir)) {
                    $context['EnvDir'] = $envDir
                }
            }

            $runConfigInfo = Get-JaxBobRunConfig -RepoRoot $repoRoot -EnvDir $envDir -Config $hook.Config -PluginConfig $pluginConfig -FlowConfig $flowConfig -Context $context @commonParams
            $context['RunConfig'] = $runConfigInfo.Config
            if (-not [string]::IsNullOrWhiteSpace($runConfigInfo.RunConfigPath)) {
                $context['RunConfigPath'] = $runConfigInfo.RunConfigPath
            }

            $libraryInfo = Get-JaxBobScenarioLibrary -RepoRoot $repoRoot -EnvDir $envDir -Config $hook.Config -FlowConfig $flowConfig -PluginConfig $pluginConfig -Context $context @commonParams
            $context['ScenarioLibrary'] = $libraryInfo.Library
            $context['ScenarioLibraryPaths'] = $libraryInfo.Paths
            Write-Debug ("[bob] BeforeSequenceResolve done RunConfigPaths={0}" -f (($context['RunConfigPaths'] | ForEach-Object { $_ }) -join ', '))
        }
    }

    $sourcePath = $MyInvocation.PSCommandPath
    if ([string]::IsNullOrWhiteSpace($sourcePath)) {
        $sourcePath = $MyInvocation.MyCommand.ScriptBlock.File
    }
    Register-JaxPlugin -Name 'bob' -Hooks $hooks -SourcePath $sourcePath

    # Register CLI flag for worktree isolation (opt-in)
    Register-JaxCliParameter -Name 'worktreeIsolation' -Aliases @('wti') -Type 'switch' -Scope 'bob'
}
