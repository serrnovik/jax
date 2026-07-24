function Resolve-JaxRunConfigImports {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Config,
        [Parameter(Mandatory = $true)]
        [string] $ConfigPath,
        [string] $RepoRoot,
        [scriptblock] $YamlReader,
        [int] $Depth = 0,
        [System.Collections.Generic.List[string]] $ImportStack,
        [System.Collections.Generic.Dictionary[string, object]] $ResolvedCache,
        [ref] $UsedPaths
    )

    if ($Depth -gt 50) {
        throw "Run-config import recursion exceeded 50 levels at '$ConfigPath'."
    }

    if ($null -eq $ImportStack) {
        $ImportStack = [System.Collections.Generic.List[string]]::new()
    }

    $useCache = $true
    if ($null -ne $UsedPaths) {
        # When collecting provenance paths, do not short-circuit via cache; we need full traversal to gather all imports.
        $useCache = $false
        $ResolvedCache = $null
    } elseif ($null -eq $ResolvedCache) {
        $ResolvedCache = New-Object 'System.Collections.Generic.Dictionary[string, object]' ([System.StringComparer]::OrdinalIgnoreCase)
    }

    $fullConfigPath = (Resolve-Path $ConfigPath).Path

    if ($useCache -and $ResolvedCache.ContainsKey($fullConfigPath)) {
        Write-Debug ("Resolve-JaxRunConfigImports cache hit: '{0}'" -f $fullConfigPath)
        if ($null -ne $UsedPaths) {
            $UsedPaths.Value += $fullConfigPath
        }
        return $ResolvedCache[$fullConfigPath]
    }

    if ($null -ne $UsedPaths) {
        $UsedPaths.Value += $fullConfigPath
    }

    $cycleIndex = $ImportStack.IndexOf($fullConfigPath)
    if ($cycleIndex -ge 0) {
        $cycle = @($ImportStack[$cycleIndex..($ImportStack.Count - 1)]) + @($fullConfigPath)
        $cycleText = $cycle -join ' -> '
        throw "Run-config import cycle detected: $cycleText"
    }
    $ImportStack.Add($fullConfigPath) | Out-Null
    Write-Debug ("Resolve-JaxRunConfigImports start (depth={0}): '{1}'" -f $Depth, $fullConfigPath)

    $imports = $null
    if ($Config.Keys -contains 'import') {
        $imports = $Config['import']
    }
    if ($null -eq $imports) {
        $ImportStack.RemoveAt($ImportStack.Count - 1)
        if ($useCache) {
            $ResolvedCache[$fullConfigPath] = $Config
        }
        return $Config
    }

    $importList = @()
    if ($imports -is [string]) {
        $importList = @($imports)
    } elseif ($imports -is [System.Collections.IEnumerable]) {
        $importList = @($imports)
    }

    $current = @{}
    foreach ($key in $Config.Keys) {
        if ($key -eq 'import') {
            continue
        }
        $current[$key] = $Config[$key]
    }

    $baseDir = Split-Path -Path $fullConfigPath -Parent
    $reader = $YamlReader
    if ($null -eq $reader) {
        $reader = {
            param($path)
            Read-JaxYaml -Path $path
        }
    }

    foreach ($importEntry in $importList) {
        if ([string]::IsNullOrWhiteSpace($importEntry)) {
            continue
        }
        $resolved = Resolve-JaxRunConfigPath -Path $importEntry -RepoRoot $RepoRoot -BaseDir $baseDir
        if (-not (Test-Path -Path $resolved -PathType Leaf)) {
            throw "Run-config import not found: '$resolved' (from '$fullConfigPath')."
        }

        Write-Verbose ("Run-config import: '{0}' -> '{1}'" -f $importEntry, $resolved)
        $importConfig = & $reader $resolved
        if ($null -eq $importConfig) {
            continue
        }
        if ($importConfig -isnot [System.Collections.IDictionary]) {
            throw "Run-config import '$resolved' did not return a map/object."
        }

        if ($null -ne $UsedPaths) {
            $importConfig = Resolve-JaxRunConfigImports -Config $importConfig -ConfigPath $resolved -RepoRoot $RepoRoot -YamlReader $reader -Depth ($Depth + 1) -ImportStack $ImportStack -ResolvedCache $ResolvedCache -UsedPaths $UsedPaths
        } else {
            $importConfig = Resolve-JaxRunConfigImports -Config $importConfig -ConfigPath $resolved -RepoRoot $RepoRoot -YamlReader $reader -Depth ($Depth + 1) -ImportStack $ImportStack -ResolvedCache $ResolvedCache
        }
        $current = Merge-JaxHashtable -Base $importConfig -Overlay $current
    }

    $ImportStack.RemoveAt($ImportStack.Count - 1)
    if ($useCache) {
        $ResolvedCache[$fullConfigPath] = $current
    }
    return $current
}
