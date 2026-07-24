function Test-JaxPluginEnabled {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [System.Collections.IDictionary] $PluginsConfig
    )

    $normalized = $Name.ToLower()
    if ($null -eq $PluginsConfig) {
        return $true
    }

    $disabled = @()
    if ($PluginsConfig.Keys -contains 'disabled') {
        $disabled = @($PluginsConfig['disabled'])
    }
    if ($disabled -contains $normalized) {
        return $false
    }

    $enabled = @()
    if ($PluginsConfig.Keys -contains 'enabled') {
        $enabled = @($PluginsConfig['enabled'])
    }
    if ($enabled.Count -gt 0) {
        return ($enabled -contains $normalized)
    }

    return $true
}
