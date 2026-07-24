function Initialize-JaxPluginsLoaded {
    [CmdletBinding()]
    param (
        [hashtable] $Context = @{},
        [System.Collections.IDictionary] $Config
    )

    Initialize-JaxPluginRegistry

    if ($script:JaxPluginsLoaded) {
        return
    }

    $repoRoot = $Context['RepoRoot']
    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        $repoRoot = Get-JaxRepoRoot
    }

    if ($null -eq $Config) {
        if ($Context.ContainsKey('Config') -and $Context['Config'] -is [System.Collections.IDictionary]) {
            $Config = $Context['Config']
        } else {
            $Config = Get-JaxConfig -RepoRoot $repoRoot
        }
    }

    Import-JaxPlugins -Config $Config -RepoRoot $repoRoot | Out-Null
    $script:JaxPluginsLoaded = $true
}
