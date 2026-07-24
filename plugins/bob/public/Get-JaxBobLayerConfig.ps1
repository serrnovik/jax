function Get-JaxBobLayerConfig {
    [CmdletBinding()]
    param (
        [string] $RepoRoot,
        [System.Collections.IDictionary] $PluginConfig,
        [hashtable] $Context = @{},
        [scriptblock] $YamlReader
    )

    $commonPSBoundParameters = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    $pluginConfig = Get-JaxBobPluginConfig -PluginConfig $PluginConfig
    $layers = @{}
    if ($pluginConfig.Keys -contains 'layers' -and $pluginConfig['layers'] -is [System.Collections.IDictionary]) {
        $layers = $pluginConfig['layers']
    }

    $repoCommonFiles = Resolve-JaxBobLayerFiles -Patterns $layers['repoCommonPatterns'] -RepoRoot $RepoRoot @commonPSBoundParameters
    $localOverrideFiles = Resolve-JaxBobLayerFiles -Patterns $layers['localOverridePatterns'] -RepoRoot $RepoRoot @commonPSBoundParameters

    $ciOverrideFiles = @()
    if (Test-JaxBobCiEnabled -Context $Context -Layers $layers) {
        $ciOverrideFiles = Resolve-JaxBobLayerFiles -Patterns $layers['ciOverridePatterns'] -RepoRoot $RepoRoot @commonPSBoundParameters
    }

    $overrideNames = @()
    if ($Context.ContainsKey('Override')) {
        $overrideNames += $Context['Override']
    }
    if ($Context.ContainsKey('Overrides')) {
        $overrideNames += $Context['Overrides']
    }
    if ($overrideNames -is [string]) {
        $overrideNames = @($overrideNames)
    }
    $overrideNames = @($overrideNames | ForEach-Object {
        if ($_ -is [string]) {
            return ($_ -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        }
        return $_
    }) | Where-Object { $_ }

    $namedOverrideFiles = @(Resolve-JaxBobOverrideFiles -OverrideNames $overrideNames -Layers $layers -RepoRoot $RepoRoot @commonPSBoundParameters)

    $flavour = $null
    if ($Context.ContainsKey('Flavour')) {
        $flavour = $Context['Flavour']
    } elseif ($Context.ContainsKey('Flavor')) {
        $flavour = $Context['Flavor']
    } elseif ($pluginConfig.Keys -contains 'flavour') {
        $flavour = $pluginConfig['flavour']
    }

    $flavourFile = Resolve-JaxBobFlavourFile -Flavour $flavour -Layers $layers -RepoRoot $RepoRoot @commonPSBoundParameters
    $flavourFiles = @()
    if (-not [string]::IsNullOrWhiteSpace($flavourFile)) {
        $flavourFiles = @($flavourFile)
    }

    $config = @{}
    $allPaths = @()
    Write-Debug ("Get-JaxBobLayerConfig: repoCommon={0} localOverride={1} ciOverride={2} namedOverride={3} flavour={4}" -f @($repoCommonFiles).Count, @($localOverrideFiles).Count, @($ciOverrideFiles).Count, @($namedOverrideFiles).Count, @($flavourFiles).Count)
    $config = Merge-JaxHashtable -Base $config -Overlay (Read-JaxBobLayerConfig -Files $repoCommonFiles -RepoRoot $RepoRoot -YamlReader $YamlReader -UsedPaths ([ref]$allPaths) @commonPSBoundParameters)
    $config = Merge-JaxHashtable -Base $config -Overlay (Read-JaxBobLayerConfig -Files $localOverrideFiles -RepoRoot $RepoRoot -YamlReader $YamlReader -UsedPaths ([ref]$allPaths) @commonPSBoundParameters)
    $config = Merge-JaxHashtable -Base $config -Overlay (Read-JaxBobLayerConfig -Files $ciOverrideFiles -RepoRoot $RepoRoot -YamlReader $YamlReader -UsedPaths ([ref]$allPaths) @commonPSBoundParameters)
    if ($namedOverrideFiles.Count -gt 0) {
        $config = Merge-JaxHashtable -Base $config -Overlay (Read-JaxBobLayerConfig -Files $namedOverrideFiles -RepoRoot $RepoRoot -YamlReader $YamlReader -UsedPaths ([ref]$allPaths) @commonPSBoundParameters)
    }
    if ($flavourFiles.Count -gt 0) {
        $config = Merge-JaxHashtable -Base $config -Overlay (Read-JaxBobLayerConfig -Files $flavourFiles -RepoRoot $RepoRoot -YamlReader $YamlReader -UsedPaths ([ref]$allPaths) @commonPSBoundParameters)
    }

    return @{
        Config = $config
        AllPaths = @($allPaths | Sort-Object -Unique)
        Paths  = @{
            repoCommon   = $repoCommonFiles
            localOverride = $localOverrideFiles
            ciOverride   = $ciOverrideFiles
            namedOverride = $namedOverrideFiles
            flavour      = $flavourFiles
        }
    }
}
