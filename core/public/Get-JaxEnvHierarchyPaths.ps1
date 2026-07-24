function Get-JaxEnvHierarchyPaths {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [System.Collections.IDictionary] $Config,
        [string] $EnvDir,
        [switch] $SkipEnvRoot
    )

    if ($null -eq $Config) {
        $Config = Get-JaxConfig -RepoRoot $RepoRoot
    }

    if ($SkipEnvRoot) {
        return @()
    }

    $envRootPath = Join-Path $RepoRoot $Config.envRoot
    if (-not (Test-Path -Path $envRootPath -PathType Container)) {
        return @()
    }

    $envRootPath = (Resolve-Path $envRootPath).Path
    $commonDirName = $Config.commonDirName
    $paths = New-Object 'System.Collections.Generic.List[string]'

    $commonPath = Join-Path $envRootPath $commonDirName
    if (Test-Path -Path $commonPath -PathType Container) {
        $paths.Add((Resolve-Path $commonPath).Path) | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($EnvDir)) {
        return @($paths)
    }
    if (-not (Test-Path -Path $EnvDir -PathType Container)) {
        return @($paths)
    }

    $resolvedEnvDir = (Resolve-Path $EnvDir).Path
    if ($resolvedEnvDir.StartsWith($envRootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $resolvedEnvDir.Substring($envRootPath.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        if (-not [string]::IsNullOrWhiteSpace($relative)) {
            $parts = @($relative -split '[\\/]' | Where-Object { $_ -ne '' })
            if ($parts.Count -gt 0) {
                $client = $parts[0]
                if ($client -ne $commonDirName) {
                    $clientCommon = Join-Path $envRootPath $client $commonDirName
                    if (Test-Path -Path $clientCommon -PathType Container) {
                        $paths.Add((Resolve-Path $clientCommon).Path) | Out-Null
                    }
                    if (-not $paths.Contains($resolvedEnvDir)) {
                        $paths.Add($resolvedEnvDir) | Out-Null
                    }
                }
            }
        }
    } else {
        if (-not $paths.Contains($resolvedEnvDir)) {
            $paths.Add($resolvedEnvDir) | Out-Null
        }
    }

    return @($paths)
}
