function Invoke-JaxModulesReload {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [string[]] $ExcludeModuleNames = @(),
        [System.Collections.IDictionary] $Config
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: RepoRoot=$RepoRoot"

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        return
    }

    $resolvedRoot = (Resolve-Path -Path $RepoRoot).Path
    $excluded = @($ExcludeModuleNames) | ForEach-Object { $_.Trim() } | Where-Object { $_ }

    # Get exclude path patterns from config
    $excludePathPatterns = @()
    if ($null -ne $Config -and $Config.ContainsKey('moduleReload') -and $Config['moduleReload'] -is [System.Collections.IDictionary]) {
        $moduleReloadConfig = $Config['moduleReload']
        if ($moduleReloadConfig.ContainsKey('excludePathPatterns')) {
            $excludePathPatterns = @($moduleReloadConfig['excludePathPatterns']) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        }
    }

    $allModules = Get-Module -All
    $removedModulePaths = @()

    foreach ($module in $allModules) {
        $modulePath = $module.Path
        if ([string]::IsNullOrWhiteSpace($modulePath)) {
            continue
        }
        if (-not $modulePath.EndsWith('.psm1')) {
            continue
        }
        if (-not $modulePath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $moduleName = Split-Path -Leaf $modulePath
        if ($excluded -contains $moduleName) {
            Write-Debug "Skipping module '$modulePath' (excluded by name)"
            continue
        }

        # Check if module path matches any exclude pattern
        $relativePath = $modulePath.Substring($resolvedRoot.Length).TrimStart(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )
        $relativePath = $relativePath.Replace('\', '/')
        $shouldExcludeByPattern = $false
        foreach ($pattern in $excludePathPatterns) {
            # Convert glob pattern to regex
            $regexPattern = '^' + [regex]::Escape($pattern).Replace('\*\*/', '.*').Replace('\*', '[^/\\]*').Replace('\?', '.') + '$'
            if ($relativePath -match $regexPattern) {
                Write-Debug "Skipping module '$modulePath' (matches exclude pattern: $pattern)"
                $shouldExcludeByPattern = $true
                break
            }
        }
        if ($shouldExcludeByPattern) {
            continue
        }

        Write-Debug "Reloading module '$modulePath'"
        Remove-Module $module -Force -ErrorAction SilentlyContinue
        $removedModulePaths += $modulePath
    }

    foreach ($modulePath in $removedModulePaths | Select-Object -Unique) {
        if (-not (Test-Path -Path $modulePath -PathType Leaf)) {
            Write-Warning "Module path not found after unload: '$modulePath'"
            continue
        }

        Import-Module $modulePath -Global -Force -DisableNameChecking -Verbose:$false -Debug:$false 1>$null 4>$null 5>$null 6>$null
    }
}
