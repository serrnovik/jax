function Get-JaxBobRunConfig {
    [CmdletBinding()]
    param (
        [string] $RepoRoot,
        [string] $EnvDir,
        [System.Collections.IDictionary] $Config,
        [System.Collections.IDictionary] $PluginConfig,
        [System.Collections.IDictionary] $FlowConfig,
        [hashtable] $Context = @{},
        [scriptblock] $YamlReader
    )

    $commonPSBoundParameters = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    $pluginConfig = Get-JaxBobPluginConfig -PluginConfig $PluginConfig
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Get-JaxRepoRoot
    }

    $runConfigPath = $null
    if ($Context.ContainsKey('RunConfigPath')) {
        $runConfigPath = $Context['RunConfigPath']
    }

    $runConfig = @{}
    $runConfigPaths = @()
    if (-not [string]::IsNullOrWhiteSpace($runConfigPath)) {
        Write-Debug ("Get-JaxBobRunConfig: using explicit RunConfigPath='{0}'" -f $runConfigPath)
        $importedPaths = @()
        $runConfig = Read-JaxRunConfigFile -Path $runConfigPath -RepoRoot $RepoRoot -YamlReader $YamlReader -UsedPaths ([ref]$importedPaths) @commonPSBoundParameters
        $runConfigPaths = if ($importedPaths.Count -gt 0) { @($importedPaths | Sort-Object -Unique) } else { @($runConfigPath) }
    } else {
        Write-Debug ("Get-JaxBobRunConfig: resolving env run-config for EnvDir='{0}'" -f $EnvDir)
        $envRunConfig = Get-JaxBobEnvRunConfig -RepoRoot $RepoRoot -EnvDir $EnvDir -Config $Config -PluginConfig $pluginConfig -YamlReader $YamlReader @commonPSBoundParameters
        $runConfig = $envRunConfig.Config
        $runConfigPaths = $envRunConfig.Paths
    }

    $defaults = @{}
    if ($pluginConfig.Keys -contains 'defaults' -and $pluginConfig['defaults'] -is [System.Collections.IDictionary]) {
        $defaults = $pluginConfig['defaults']
    }

    $envConfig = $null
    if ($Context.ContainsKey('RunConfigEnv')) {
        $envConfig = $Context['RunConfigEnv']
    }

    $repoConfig = $null
    $selectedEnv = $null
    if ($Context.ContainsKey('SelectedEnv')) {
        $selectedEnv = $Context['SelectedEnv']
    }
    $isComputedEnv = $false
    if ($null -ne $selectedEnv -and $selectedEnv.PSObject.Properties.Match('IsComputed').Count -gt 0 -and $selectedEnv.IsComputed) {
        $isComputedEnv = $true
    }
    if ($Context.ContainsKey('RunConfigRepo')) {
        $repoConfig = $Context['RunConfigRepo']
    } elseif ($isComputedEnv) {
        $repoConfig = @{}
        $Context['RunConfigLayerPaths'] = @{}
        $Context['RunConfigLayerAllPaths'] = @()
    } else {
        $layerInfo = Get-JaxBobLayerConfig -RepoRoot $RepoRoot -PluginConfig $pluginConfig -Context $Context -YamlReader $YamlReader @commonPSBoundParameters
        $repoConfig = $layerInfo.Config
        $Context['RunConfigLayerPaths'] = $layerInfo.Paths
        if ($layerInfo.ContainsKey('AllPaths')) {
            $Context['RunConfigLayerAllPaths'] = $layerInfo.AllPaths
        }
    }

    $userConfig = $null
    if ($Context.ContainsKey('RunConfigUser')) {
        $userConfig = $Context['RunConfigUser']
    }
    $cliOverrides = $null
    if ($Context.ContainsKey('RunConfigOverrides')) {
        $cliOverrides = $Context['RunConfigOverrides']
    }

    Write-Debug ("Get-JaxBobRunConfig: merging layers (defaults/run/env/repo/user/cli)")
    $merged = Merge-JaxRunConfigLayers -Defaults $defaults -RunConfig $runConfig -EnvConfig $envConfig -RepoConfig $repoConfig -UserConfig $userConfig -CliOverrides $cliOverrides @commonPSBoundParameters

    # Back-compat: expose flow suite under boss.suite.* (and flow.suite.*) to tasks.
    # This matches legacy expectations where "boss" was the flow domain.
    if ($FlowConfig -is [System.Collections.IDictionary] -and $FlowConfig.ContainsKey('suite') -and $FlowConfig['suite'] -is [System.Collections.IDictionary]) {
        $suite = $FlowConfig['suite']
        $suiteClient = if ($suite.ContainsKey('client')) { [string]$suite['client'] } else { $null }
        $suiteEnvType = if ($suite.ContainsKey('env_type')) { [string]$suite['env_type'] } else { $null }
        $suiteName = if ($suite.ContainsKey('name')) { [string]$suite['name'] } else { $null }

        $suiteEnv = $null
        if ($suite.ContainsKey('env')) {
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
        if ([string]::IsNullOrWhiteSpace([string]$suiteEnv)) {
            if (-not [string]::IsNullOrWhiteSpace($suiteClient) -and -not [string]::IsNullOrWhiteSpace($suiteEnvType)) {
                $suiteEnv = "{0}/{1}" -f $suiteClient, $suiteEnvType
            } else {
                $suiteEnv = $suiteClient
            }
        }

        $suiteVersion = $null
        if ($suite.ContainsKey('version') -and $suite['version'] -is [System.Collections.IDictionary]) {
            $suiteVersion = $suite['version']
        }

        $suiteVars = @{
            suite = @{
                name     = $suiteName
                client   = $suiteClient
                env_type = $suiteEnvType
                env      = $suiteEnv
            }
        }
        if ($null -ne $suiteVersion) {
            $suiteVars.suite['version'] = $suiteVersion
        }
        $varsFlow = @{
            boss = $suiteVars
            flow = $suiteVars
        }

        if ($merged -is [System.Collections.IDictionary]) {
            # Only add if missing; do not clobber an explicitly provided boss/flow tree.
            $hasBossSuite = $false
            if ($merged.ContainsKey('boss') -and $merged['boss'] -is [System.Collections.IDictionary]) {
                $b = $merged['boss']
                if ($b.ContainsKey('suite')) { $hasBossSuite = $true }
            }
            if (-not $hasBossSuite) {
                $merged = Merge-JaxHashtable -Base $varsFlow -Overlay $merged @commonPSBoundParameters
            }
        }
    }

    if ($pluginConfig.ContainsKey('expandVariables') -and $pluginConfig['expandVariables']) {
        $varsOverride = $null
        if ($Context.ContainsKey('VariablesOverride')) {
            $varsOverride = $Context['VariablesOverride']
        }
        $ignoreMissing = $false
        if ($pluginConfig.ContainsKey('ignoreMissingPlaceholders')) {
            $ignoreMissing = [bool]$pluginConfig['ignoreMissingPlaceholders']
        } elseif ($pluginConfig.ContainsKey('ignoreMissingVariables')) {
            $ignoreMissing = [bool]$pluginConfig['ignoreMissingVariables']
        }
        $sourcePaths = @()
        if ($runConfigPaths.Count -gt 0) {
            $sourcePaths += $runConfigPaths
        }
        if ($Context.ContainsKey('RunConfigLayerPaths') -and $Context['RunConfigLayerPaths'] -is [System.Collections.IDictionary]) {
            $layerPaths = $Context['RunConfigLayerPaths']
            foreach ($k in @($layerPaths.Keys)) {
                $v = $layerPaths[$k]
                if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) {
                    $sourcePaths += @($v)
                } elseif ($v -is [string]) {
                    $sourcePaths += @($v)
                }
            }
        }
        if ($Context.ContainsKey('RunConfigLayerAllPaths') -and $Context['RunConfigLayerAllPaths'] -is [System.Collections.IEnumerable]) {
            $sourcePaths += @($Context['RunConfigLayerAllPaths'])
        }
        $sourcePaths = @($sourcePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

        Write-Debug ("Get-JaxBobRunConfig: expanding variables (ignoreMissing={0}) sourcePaths={1}" -f $ignoreMissing, $sourcePaths.Count)
        $merged = Expand-JaxPlaceholders -Config $merged -Override $varsOverride -SourcePaths $sourcePaths -ignoreMissingPlaceholders:$ignoreMissing -DontThrow:$ignoreMissing @commonPSBoundParameters
    }

    if ($merged -is [System.Collections.IDictionary]) {
        if ($Context.ContainsKey('SuppressRunConfigLog') -and [bool]$Context['SuppressRunConfigLog']) {
            Write-Debug "Get-JaxBobRunConfig: SuppressRunConfigLog=true (skipping run-config log write)"
            return @{
                Config        = $merged
                RunConfigPath = $runConfigPath
            }
        }
        if (-not $Context.ContainsKey('RunConfigLogPath') -or [string]::IsNullOrWhiteSpace([string]$Context['RunConfigLogPath'])) {
            $logPath = Write-JaxRunConfigLog -RunConfig $merged -RepoRoot $RepoRoot
            $Context['RunConfigLogPath'] = $logPath
            Write-Host ("🪵 → 🔢 Run config saved (jaxfile merged layers): {0}" -f (Format-JaxPathLink -Path $logPath))
        } else {
            Write-Debug ("Get-JaxBobRunConfig: run config already logged at '{0}'" -f $Context['RunConfigLogPath'])
        }
    }

    if ($runConfigPaths.Count -gt 0) {
        $Context['RunConfigPaths'] = $runConfigPaths
    }

    return @{
        Config        = $merged
        RunConfigPath = $runConfigPath
    }
}
