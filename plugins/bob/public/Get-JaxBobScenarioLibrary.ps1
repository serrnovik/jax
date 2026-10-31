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
            if ($null -eq $suiteLibrary) {
                # Boss files write `library:` with nothing under it.
            } elseif ($suiteLibrary -isnot [System.Collections.IDictionary]) {
                throw "suite.library must be a map/object."
            } else {
                $library = Merge-JaxHashtable -Base $library -Overlay $suiteLibrary
            }
        }
    }

    $expand = $true
    if ($pluginConfig.ContainsKey('expandVariables')) {
        $expand = [bool] $pluginConfig['expandVariables']
    }

    if ($expand -and $library.Count -gt 0) {
        # Library files are written against the merged bobfile (`{{ module.* }}`),
        # which lives on the run config. Hook variables (env.git.root, boss.suite)
        # stay on top when both define the same key.
        $varsOverride = @{}
        if ($Context.ContainsKey('RunConfig') -and $Context['RunConfig'] -is [System.Collections.IDictionary]) {
            $varsOverride = $Context['RunConfig']
        }
        if ($Context.ContainsKey('VariablesOverride') -and $Context['VariablesOverride'] -is [System.Collections.IDictionary]) {
            $varsOverride = Merge-JaxHashtable -Base $varsOverride -Overlay $Context['VariablesOverride']
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
