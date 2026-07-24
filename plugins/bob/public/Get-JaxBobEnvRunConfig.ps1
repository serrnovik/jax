function Get-JaxBobEnvRunConfig {
    [CmdletBinding()]
    param (
        [string] $RepoRoot,
        [string] $EnvDir,
        [System.Collections.IDictionary] $Config,
        [System.Collections.IDictionary] $PluginConfig,
        [scriptblock] $YamlReader
    )

    $commonPSBoundParameters = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    if ([string]::IsNullOrWhiteSpace($EnvDir)) {
        return @{
            Config = @{}
            Paths  = @()
        }
    }

    $pluginConfig = Get-JaxBobPluginConfig -PluginConfig $PluginConfig
    $paths = Get-JaxEnvHierarchyPaths -RepoRoot $RepoRoot -Config $Config -EnvDir $EnvDir
    $merged = @{}
    $usedPaths = @()

    foreach ($path in $paths) {
        $runConfigPath = Resolve-JaxRunConfigFile -EnvDir $path -Config $Config -PluginConfig $pluginConfig @commonPSBoundParameters
        if ([string]::IsNullOrWhiteSpace($runConfigPath)) {
            continue
        }
        Write-Debug ("Get-JaxBobEnvRunConfig: applying '{0}'" -f $runConfigPath)
        $importedPaths = @()
        $configPart = Read-JaxRunConfigFile -Path $runConfigPath -RepoRoot $RepoRoot -YamlReader $YamlReader -UsedPaths ([ref]$importedPaths) @commonPSBoundParameters
        $merged = Merge-JaxHashtable -Base $merged -Overlay $configPart
        if ($importedPaths.Count -gt 0) {
            $usedPaths += $importedPaths
        } else {
            $usedPaths += $runConfigPath
        }
    }

    return @{
        Config = $merged
        Paths  = @($usedPaths | Sort-Object -Unique)
    }
}
