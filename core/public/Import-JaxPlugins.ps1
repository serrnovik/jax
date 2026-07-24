function Import-JaxPlugins {
    [CmdletBinding()]
    param (
        [System.Collections.IDictionary] $Config,
        [string] $RepoRoot = (Get-JaxRepoRoot)
    )

    Initialize-JaxPluginRegistry

    if ($null -eq $Config) {
        $Config = Get-JaxConfig -RepoRoot $RepoRoot
    }

    $pluginsConfig = Get-JaxPluginConfig -Config $Config
    $enabled = @()
    $paths = @()
    if ($pluginsConfig.Keys -contains 'enabled') {
        $enabled = @($pluginsConfig['enabled'])
    }
    if ($pluginsConfig.Keys -contains 'paths') {
        $paths = @($pluginsConfig['paths'])
    }

    foreach ($path in $paths) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }
        $resolved = Resolve-JaxRepoRootedPath -Path $path -RepoRoot $RepoRoot
        if (Test-Path -Path $resolved -PathType Leaf) {
            # Import plugins into global session state so their initialization can reliably see Jax.Core exports.
            Import-Module $resolved -Global -Force -DisableNameChecking | Out-Null
        } else {
            Write-Debug "Jax plugin path not found: $resolved"
        }
    }

    foreach ($name in $enabled) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }
        if (-not (Test-JaxPluginEnabled -Name $name -PluginsConfig $pluginsConfig)) {
            continue
        }
        $pluginPath = Get-JaxBuiltinPluginPath -Name $name
        if ([string]::IsNullOrWhiteSpace($pluginPath)) {
            Write-Debug "No built-in plugin path for '$name'"
            continue
        }
        if (Test-Path -Path $pluginPath -PathType Leaf) {
            # Import built-in plugins into global session state so their initialization can reliably see Jax.Core exports.
            Import-Module $pluginPath -Global -Force -DisableNameChecking | Out-Null
        } else {
            Write-Debug "Built-in plugin module not found: $pluginPath"
        }
    }

    return Get-JaxPlugins
}
