function Invoke-JaxHooks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [hashtable] $Context = @{},
        $Data
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: Name=$Name"

    if ($Context.ContainsKey('SkipPlugins') -and $Context['SkipPlugins']) {
        return
    }

    $config = $null
    if ($Context.ContainsKey('Config') -and $Context['Config'] -is [System.Collections.IDictionary]) {
        $config = $Context['Config']
    }

    $allowAutoLoad = $false
    if ($Context.ContainsKey('AllowAutoPluginLoad') -and $Context['AllowAutoPluginLoad']) {
        $allowAutoLoad = $true
    }
    if (-not $allowAutoLoad -and $null -eq $config -and -not $Context.ContainsKey('RepoRoot')) {
        return
    }

    Initialize-JaxPluginsLoaded -Context $Context -Config $config @commonParams

    if ($null -eq $config) {
        if ($Context.ContainsKey('RepoRoot') -and -not [string]::IsNullOrWhiteSpace($Context['RepoRoot'])) {
            $config = Get-JaxConfig -RepoRoot $Context['RepoRoot'] @commonParams
        } else {
            $config = Get-JaxConfig @commonParams
        }
    }

    $pluginsConfig = Get-JaxPluginConfig -Config $config @commonParams
    $plugins = Get-JaxPlugins @commonParams
    foreach ($plugin in $plugins) {
        if (-not (Test-JaxPluginEnabled -Name $plugin.Name -PluginsConfig $pluginsConfig @commonParams)) {
            continue
        }
        $hooks = $plugin.Hooks
        if ($null -eq $hooks -or -not ($hooks -is [System.Collections.IDictionary])) {
            continue
        }
        if (-not $hooks.Contains($Name)) {
            continue
        }

        $handler = $hooks[$Name]
        $handlers = @()
        if ($handler -is [scriptblock]) {
            $handlers = @($handler)
        } elseif ($handler -is [System.Collections.IEnumerable]) {
            $handlers = @($handler)
        }

        $pluginConfig = @{}
        if ($pluginsConfig.Keys -contains 'config' -and $pluginsConfig['config'] -is [System.Collections.IDictionary]) {
            $pluginConfigSource = $pluginsConfig['config']
            if ($pluginConfigSource.Keys -contains $plugin.Name) {
                $pluginConfig = $pluginConfigSource[$plugin.Name]
            }
        }

        foreach ($hookHandler in $handlers) {
            $hookContext = @{
                Name         = $Name
                Plugin       = $plugin
                Config       = $config
                PluginConfig = $pluginConfig
                Context      = $Context
                Data         = $Data
            }
            & $hookHandler $hookContext
        }
    }
}
