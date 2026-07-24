function Get-JaxConfig {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [string] $UserConfigPath = (Join-Path $HOME '.jax/config.yml'),
        [System.Collections.IDictionary] $Overrides,
        [switch] $SkipUserConfig
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $defaultConfig = Get-JaxDefaultConfig

    $repoConfigPath = Get-JaxRepoConfigPath -RepoRoot $RepoRoot
    $legacyRepoConfigPath = Join-Path $RepoRoot 'jax.config.yml'
    $repoConfig = $null
    if (Test-Path -Path $repoConfigPath -PathType Leaf) {
        $repoConfig = Read-JaxYaml -Path $repoConfigPath
    } elseif (Test-Path -Path $legacyRepoConfigPath -PathType Leaf) {
        $repoConfig = Read-JaxYaml -Path $legacyRepoConfigPath
    }
    if ($null -ne $repoConfig) {
        $repoConfig = Resolve-JaxConfigSection -Config $repoConfig
        $repoSourcePath = $legacyRepoConfigPath
        if ($repoConfigPath -and (Test-Path -Path $repoConfigPath -PathType Leaf)) {
            $repoSourcePath = $repoConfigPath
        }
        Confirm-JaxConfig -Config $repoConfig -SourcePath $repoSourcePath
    }

    $userConfig = $null
    if (-not $SkipUserConfig -and -not [string]::IsNullOrWhiteSpace($UserConfigPath) -and (Test-Path -Path $UserConfigPath -PathType Leaf)) {
        $userConfig = Read-JaxYaml -Path $UserConfigPath
        if ($null -ne $userConfig) {
            $userConfig = Resolve-JaxConfigSection -Config $userConfig
            Confirm-JaxConfig -Config $userConfig -SourcePath $UserConfigPath
        }
    }

    $mergedConfig = $defaultConfig
    if ($null -ne $repoConfig) {
        $mergedConfig = Merge-JaxHashtable -Base $mergedConfig -Overlay $repoConfig
    }
    if ($null -ne $userConfig) {
        $mergedConfig = Merge-JaxHashtable -Base $mergedConfig -Overlay $userConfig
    }
    if ($null -ne $Overrides) {
        Confirm-JaxConfig -Config $Overrides -SourcePath 'overrides'
        $mergedConfig = Merge-JaxHashtable -Base $mergedConfig -Overlay $Overrides
    }

    # When .jax/jax.shortcut.yml exists, it is the only source of shortcuts (supersedes shortcuts in jax.config.yml).
    # This keeps bookmark-style edits and emojis in jax.config.yml intact when -ssc/-rsc rewrites config.
    $shortcutFilePath = Get-JaxRepoShortcutFilePath -RepoRoot $RepoRoot @commonParams
    if (Test-Path -Path $shortcutFilePath -PathType Leaf) {
        $sfYaml = Read-JaxYaml -Path $shortcutFilePath
        $sfCfg = $null
        if ($null -ne $sfYaml) {
            $sfCfg = Resolve-JaxConfigSection -Config $sfYaml
            if ($null -ne $sfCfg) {
                Confirm-JaxConfig -Config $sfCfg -SourcePath $shortcutFilePath
            }
        }
        if ($null -ne $sfCfg -and $sfCfg.Keys -contains 'shortcuts' -and $sfCfg['shortcuts'] -is [System.Collections.IDictionary]) {
            $mergedConfig['shortcuts'] = $sfCfg['shortcuts']
        } else {
            $mergedConfig['shortcuts'] = @{}
        }
    }

    # Plugin enablement is repo-owned: user config can add plugins, but should not
    # accidentally remove required repo plugins by replacing the enabled list.
    if ($mergedConfig.Keys -contains 'plugins' -and $mergedConfig['plugins'] -is [System.Collections.IDictionary]) {
        $plugins = $mergedConfig['plugins']
        $repoPlugins = $null
        if ($null -ne $repoConfig -and $repoConfig.Keys -contains 'plugins' -and $repoConfig['plugins'] -is [System.Collections.IDictionary]) {
            $repoPlugins = $repoConfig['plugins']
        }
        $userPlugins = $null
        if ($null -ne $userConfig -and $userConfig.Keys -contains 'plugins' -and $userConfig['plugins'] -is [System.Collections.IDictionary]) {
            $userPlugins = $userConfig['plugins']
        }

        $repoEnabled = @()
        $repoDisabled = @()
        $userEnabled = @()
        $userDisabled = @()

        if ($null -ne $repoPlugins -and $repoPlugins.Keys -contains 'enabled') { $repoEnabled = @($repoPlugins['enabled']) }
        if ($null -ne $repoPlugins -and $repoPlugins.Keys -contains 'disabled') { $repoDisabled = @($repoPlugins['disabled']) }
        if ($null -ne $userPlugins -and $userPlugins.Keys -contains 'enabled') { $userEnabled = @($userPlugins['enabled']) }
        if ($null -ne $userPlugins -and $userPlugins.Keys -contains 'disabled') { $userDisabled = @($userPlugins['disabled']) }

        $repoEnabled = @($repoEnabled | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.ToLower() })
        $repoDisabled = @($repoDisabled | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.ToLower() })
        $userEnabled = @($userEnabled | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.ToLower() })
        $userDisabled = @($userDisabled | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.ToLower() })

        if ($repoEnabled.Count -gt 0) {
            $finalEnabled = @($repoEnabled)
            foreach ($name in $userEnabled) {
                if ($finalEnabled -notcontains $name) { $finalEnabled += $name }
            }
            $finalDisabled = @($repoDisabled)
            foreach ($name in $userDisabled) {
                if ($finalDisabled -notcontains $name) { $finalDisabled += $name }
            }
            $finalEnabled = @($finalEnabled | Where-Object { $finalDisabled -notcontains $_ })

            $plugins['enabled'] = $finalEnabled
            $plugins['disabled'] = $finalDisabled
            $mergedConfig['plugins'] = $plugins
        }
    }

    $mergedConfig = Convert-JaxConfig -Config $mergedConfig
    Confirm-JaxConfig -Config $mergedConfig -SourcePath 'merged'

    return $mergedConfig
}
