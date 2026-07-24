function Resolve-JaxBobFlavourFile {
    [CmdletBinding()]
    param (
        [string] $Flavour,
        [System.Collections.IDictionary] $Layers,
        [string] $RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($Flavour)) {
        return $null
    }

    if ($Flavour.Contains('/') -or $Flavour.Contains('\\') -or $Flavour.EndsWith('.yml') -or $Flavour.EndsWith('.yaml')) {
        $resolved = Resolve-JaxRunConfigPath -Path $Flavour -RepoRoot $RepoRoot -BaseDir $RepoRoot
        if (Test-Path -Path $resolved -PathType Leaf) {
            return (Resolve-Path $resolved).Path
        }
        return $null
    }

    $dir = $null
    if ($null -ne $Layers -and $Layers.ContainsKey('flavourDir')) {
        $dir = $Layers['flavourDir']
    }
    if ([string]::IsNullOrWhiteSpace($dir)) {
        $dir = 'configs/jax-flavours'
    }

    $dir = Resolve-JaxRunConfigPath -Path $dir -RepoRoot $RepoRoot -BaseDir $RepoRoot
    if (-not (Test-Path -Path $dir -PathType Container)) {
        return $null
    }

    $patterns = @()
    if ($null -ne $Layers -and $Layers.ContainsKey('flavourPatterns')) {
        $patterns = @($Layers['flavourPatterns'])
    }
    if ($patterns.Count -eq 0) {
        $patterns = @('*.yml', '*.yaml')
    }

    foreach ($pattern in $patterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            continue
        }
        $ext = $pattern.Trim()
        if ($ext.StartsWith('*')) {
            $ext = $ext.TrimStart('*')
        }
        if (-not $ext.StartsWith('.')) {
            $ext = ".$ext"
        }
        $candidate = Join-Path $dir "$Flavour$ext"
        if (Test-Path -Path $candidate -PathType Leaf) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}
