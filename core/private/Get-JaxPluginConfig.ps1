function Get-JaxPluginConfig {
    [CmdletBinding()]
    param (
        [System.Collections.IDictionary] $Config
    )

    if ($null -eq $Config) {
        return @{}
    }
    if ($Config.Keys -contains 'plugins' -and $Config['plugins'] -is [System.Collections.IDictionary]) {
        return $Config['plugins']
    }
    return @{}
}
