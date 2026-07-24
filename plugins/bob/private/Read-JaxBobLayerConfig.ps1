function Read-JaxBobLayerConfig {
    [CmdletBinding()]
    param (
        [System.Collections.IEnumerable] $Files,
        [string] $RepoRoot,
        [scriptblock] $YamlReader,
        [ref] $UsedPaths
    )

    $merged = @{}
    if ($null -eq $Files) {
        return $merged
    }

    foreach ($file in $Files) {
        if ([string]::IsNullOrWhiteSpace($file)) {
            continue
        }
        $configPart = Read-JaxRunConfigFile -Path $file -RepoRoot $RepoRoot -YamlReader $YamlReader -UsedPaths $UsedPaths
        $merged = Merge-JaxHashtable -Base $merged -Overlay $configPart
    }

    return $merged
}
