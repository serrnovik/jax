function Get-JaxPlugins {
    [CmdletBinding()]
    param ()

    Initialize-JaxPluginRegistry
    return @($script:JaxPluginRegistry)
}
