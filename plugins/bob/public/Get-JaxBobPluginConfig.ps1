function Get-JaxBobPluginConfig {
    [CmdletBinding()]
    param (
        [System.Collections.IDictionary] $PluginConfig
    )

    $defaults = Get-JaxBobPluginDefaults
    if ($null -eq $PluginConfig) {
        return $defaults
    }
    if (-not ($PluginConfig -is [System.Collections.IDictionary])) {
        return $defaults
    }

    return (Merge-JaxHashtable -Base $defaults -Overlay $PluginConfig)
}
