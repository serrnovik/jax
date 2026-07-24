function Get-JaxBobScenarioLibrary {
    [CmdletBinding()]
    param (
        [string] $RepoRoot,
        [string] $EnvDir,
        [System.Collections.IDictionary] $Config,
        [System.Collections.IDictionary] $FlowConfig,
        [System.Collections.IDictionary] $PluginConfig,
        [hashtable] $Context = @{},
        [scriptblock] $YamlReader
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Get-JaxRepoRoot
    }
    if ($null -eq $Config) {
        $Config = Get-JaxConfig -RepoRoot $RepoRoot
    }

    $pluginConfig = Get-JaxBobPluginConfig -PluginConfig $PluginConfig
    $files = Resolve-JaxBobScenarioLibraryFiles -RepoRoot $RepoRoot -EnvDir $EnvDir -Config $Config

    $reader = $YamlReader
    if ($null -eq $reader) {
        $reader = {
            param($path)
            Read-JaxYaml -Path $path
        }
    }

    $library = @{}
    foreach ($file in $files) {
        $part = & $reader $file
        if ($null -eq $part) {
            continue
        }
        if ($part -isnot [System.Collections.IDictionary]) {
            throw "Scenario library '$file' did not return a map/object."
        }
        $library = Merge-JaxHashtable -Base $library -Overlay $part
    }

    if ($FlowConfig -and $FlowConfig.Keys -contains 'suite') {
        $suite = $FlowConfig['suite']
        if ($suite -is [System.Collections.IDictionary] -and ($suite.Keys -contains 'library')) {
            $suiteLibrary = $suite['library']
            if ($suiteLibrary -isnot [System.Collections.IDictionary]) {
                throw "suite.library must be a map/object."
            }
            $library = Merge-JaxHashtable -Base $library -Overlay $suiteLibrary
        }
    }

    $expand = $true
    if ($pluginConfig.ContainsKey('expandVariables')) {
        $expand = [bool] $pluginConfig['expandVariables']
    }

    if ($expand -and $library.Count -gt 0) {
        $varsOverride = $null
        if ($Context.ContainsKey('VariablesOverride')) {
            $varsOverride = $Context['VariablesOverride']
        }
        $ignoreMissing = $false
        if ($pluginConfig.ContainsKey('ignoreMissingPlaceholders')) {
            $ignoreMissing = [bool] $pluginConfig['ignoreMissingPlaceholders']
        } elseif ($pluginConfig.ContainsKey('ignoreMissingVariables')) {
            $ignoreMissing = [bool] $pluginConfig['ignoreMissingVariables']
        }
        $library = Expand-JaxPlaceholders -Config $library -Override $varsOverride -ignoreMissingPlaceholders:$ignoreMissing -DontThrow:$ignoreMissing
    }

    return @{
        Library = $library
        Paths   = $files
    }
}
