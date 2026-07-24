function Get-JaxRepoRoot {
    [CmdletBinding()]
    param (
        [string] $StartPath = (Get-Location).Path,
        [switch] $Exact
    )

    $startPathWasExplicit = $PSBoundParameters.ContainsKey('StartPath')
    if ($Exact) {
        if (-not (Test-Path -LiteralPath $StartPath -PathType Container)) {
            throw "Repository root does not exist or is not a directory: $StartPath"
        }
        return (Resolve-Path -LiteralPath $StartPath).Path
    }
    if (-not $startPathWasExplicit) {
        $envOverride = $env:JAX_REPO_ROOT
        if (-not [string]::IsNullOrWhiteSpace($envOverride) -and (Test-Path -LiteralPath $envOverride -PathType Container)) {
            return (Resolve-Path -LiteralPath $envOverride).Path
        }
    }

    $resolvedStart = $StartPath
    if (Test-Path -LiteralPath $StartPath -PathType Container) {
        $resolvedStart = (Resolve-Path -LiteralPath $StartPath).Path
    }

    $gitCommand = Get-Command -Name git -ErrorAction SilentlyContinue
    if ($null -ne $gitCommand) {
        try {
            $gitRoot = & git -C $resolvedStart rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
                return (Resolve-Path $gitRoot).Path
            }
        } catch {
        }
    }

    $current = $resolvedStart
    while ($true) {
        $gitMarker = Join-Path $current '.git'
        if (Test-Path -Path $gitMarker) {
            return $current
        }
        $parent = Split-Path $current -Parent
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
            break
        }
        $current = $parent
    }

    return $resolvedStart
}
