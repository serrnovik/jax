function Initialize-JaxPluginRegistry {
    [CmdletBinding()]
    param ()

    if (-not (Get-Variable -Name JaxPluginRegistry -Scope Script -ErrorAction SilentlyContinue)) {
        $script:JaxPluginRegistry = @()
    }
    if (-not (Get-Variable -Name JaxPluginsLoaded -Scope Script -ErrorAction SilentlyContinue)) {
        $script:JaxPluginsLoaded = $false
    }
}
