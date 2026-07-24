function Resolve-JaxBobOverrideFiles {
    [CmdletBinding()]
    param (
        [string[]] $OverrideNames,
        [System.Collections.IDictionary] $Layers,
        [string] $RepoRoot
    )

    if ($null -eq $OverrideNames -or $OverrideNames.Count -eq 0) {
        return @()
    }

    $map = @{}
    if ($null -ne $Layers -and $Layers.ContainsKey('overrides') -and $Layers['overrides'] -is [System.Collections.IDictionary]) {
        $map = $Layers['overrides']
    }

    $files = @()
    foreach ($name in $OverrideNames) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }
        $trimmed = $name.Trim()
        $paths = @()

        if ($map.Keys -contains $trimmed) {
            $entry = $map[$trimmed]
            if ($entry -is [string]) {
                $paths = @($entry)
            } elseif ($entry -is [System.Collections.IEnumerable]) {
                $paths = @($entry)
            }
        } elseif ($trimmed.Contains('/') -or $trimmed.Contains('\\') -or $trimmed.EndsWith('.yml') -or $trimmed.EndsWith('.yaml')) {
            $paths = @($trimmed)
        }

        foreach ($path in $paths) {
            if ([string]::IsNullOrWhiteSpace($path)) {
                continue
            }
            if ($path.Contains('*') -or $path.Contains('?')) {
                $files += Resolve-JaxBobLayerFiles -Patterns @($path) -RepoRoot $RepoRoot
                continue
            }
            $resolved = Resolve-JaxRunConfigPath -Path $path -RepoRoot $RepoRoot -BaseDir $RepoRoot
            if (Test-Path -Path $resolved -PathType Leaf) {
                $files += (Resolve-Path $resolved).Path
            }
        }
    }

    return @($files | Sort-Object -Unique)
}
