function Get-JaxVaultPluginConfig {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [System.Collections.IDictionary] $Config
    )

    if ($null -eq $Config) {
        $Config = Get-JaxConfig -RepoRoot $RepoRoot
    }

    if ($null -eq $Config -or -not ($Config -is [System.Collections.IDictionary])) {
        return @{}
    }

    if (-not ($Config.Contains('plugins'))) { return @{} }
    $plugins = $Config['plugins']
    if ($null -eq $plugins -or -not ($plugins -is [System.Collections.IDictionary])) { return @{} }
    if (-not ($plugins.Contains('config'))) { return @{} }
    $pluginConfig = $plugins['config']
    if ($null -eq $pluginConfig -or -not ($pluginConfig -is [System.Collections.IDictionary])) { return @{} }
    if (-not ($pluginConfig.Contains('vault'))) { return @{} }

    $vaultConfig = $pluginConfig['vault']
    if ($null -eq $vaultConfig -or -not ($vaultConfig -is [System.Collections.IDictionary])) { return @{} }

    return $vaultConfig
}
