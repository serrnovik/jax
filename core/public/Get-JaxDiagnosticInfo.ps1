function Get-JaxDiagnosticInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $RuntimeRoot,
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot
    )

    $runtimeRoot = [IO.Path]::GetFullPath($RuntimeRoot)
    $repoRoot = [IO.Path]::GetFullPath($RepoRoot)
    $warnings = [System.Collections.Generic.List[string]]::new()
    $display = [ordered]@{}

    $versionPath = Join-Path $runtimeRoot 'VERSION'
    $version = if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
        (Get-Content -LiteralPath $versionPath -Raw).Trim()
    } else {
        'unknown'
        $warnings.Add("Version file is missing: $versionPath")
    }

    $installationPath = Join-Path $runtimeRoot 'INSTALLATION.json'
    $installation = $null
    if (Test-Path -LiteralPath $installationPath -PathType Leaf) {
        try {
            $installation = Get-Content -LiteralPath $installationPath -Raw | ConvertFrom-Json
        } catch {
            $warnings.Add("Installation metadata could not be read: $installationPath")
        }
    }

    $sourceCommit = if ($null -ne $installation -and -not [string]::IsNullOrWhiteSpace([string]$installation.SourceCommit)) {
        [string]$installation.SourceCommit
    } elseif (Get-Command -Name git -ErrorAction SilentlyContinue) {
        try {
            $commit = & git -C $runtimeRoot rev-parse HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commit)) { $commit.Trim() } else { 'unknown' }
        } catch { 'unknown' }
    } else {
        'unknown'
    }

    $gitRoot = $null
    $gitBranch = 'not a Git repository'
    $gitCommit = 'unknown'
    $gitStatus = 'unknown'
    if (Get-Command -Name git -ErrorAction SilentlyContinue) {
        try {
            $candidate = & git -C $repoRoot rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($candidate)) {
                $gitRoot = [IO.Path]::GetFullPath($candidate.Trim())
                $branch = & git -C $gitRoot branch --show-current 2>$null
                $gitBranch = if ([string]::IsNullOrWhiteSpace($branch)) { 'detached HEAD' } else { $branch.Trim() }
                $commit = & git -C $gitRoot rev-parse --short HEAD 2>$null
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commit)) { $gitCommit = $commit.Trim() }
                $changes = @(& git -C $gitRoot status --porcelain 2>$null)
                $gitStatus = if ($changes.Count -eq 0) { 'clean' } else { "modified ($($changes.Count) entries)" }
            }
        } catch {
            $warnings.Add('Git repository details could not be read.')
        }
    } else {
        $warnings.Add('Git is unavailable; repository identification is limited.')
    }

    $repoConfigPath = Get-JaxRepoConfigPath -RepoRoot $repoRoot
    $legacyConfigPath = Join-Path $repoRoot 'jax.config.yml'
    $userConfigPath = Join-Path $HOME '.jax/config.yml'
    $statePath = Get-JaxStatePath -RepoRoot $repoRoot
    $repoConfigState = if (Test-Path -LiteralPath $repoConfigPath -PathType Leaf) {
        'present (.jax/jax.config.yml)'
    } elseif (Test-Path -LiteralPath $legacyConfigPath -PathType Leaf) {
        'present (legacy jax.config.yml)'
    } else {
        'missing'
        $warnings.Add('Repository configuration is missing. Run `jax init` to create it.')
    }

    $configurationState = 'not loaded'
    $environmentRootState = 'unknown'
    try {
        $config = Get-JaxConfig -RepoRoot $repoRoot
        $configurationState = 'loaded'
        $envRoot = if ($config.Contains('envRoot')) {
            [string]$config['envRoot']
        } else {
            'env'
        }
        $environmentRootState = if (Test-Path -LiteralPath (Join-Path $repoRoot $envRoot) -PathType Container) {
            "present ($envRoot/)"
        } else {
            "missing ($envRoot/)"
            $warnings.Add("Environment root is missing: $envRoot/")
        }
    } catch {
        $configurationState = "invalid: $($_.Exception.Message)"
        $warnings.Add('Configuration could not be loaded; inspect the error above before running tasks.')
    }

    $display['Version'] = $version
    $display['Runtime root'] = $runtimeRoot
    $display['Install source commit'] = $sourceCommit
    $display['Installed at (UTC)'] = if ($null -ne $installation -and $installation.InstalledAtUtc) { [string]$installation.InstalledAtUtc } else { 'source checkout or unknown' }
    $display['Current directory'] = (Get-Location).Path
    $display['Target repository'] = $repoRoot
    $display['Git root'] = if ($gitRoot) { $gitRoot } else { 'not a Git repository' }
    $display['Git branch'] = $gitBranch
    $display['Git commit'] = $gitCommit
    $display['Git status'] = $gitStatus
    $display['Repository config'] = $repoConfigState
    $display['User config'] = if (Test-Path -LiteralPath $userConfigPath -PathType Leaf) { 'present (~/.jax/config.yml)' } else { 'absent (optional)' }
    $display['Local state'] = if (Test-Path -LiteralPath $statePath -PathType Leaf) { 'present (.jax/state.yml)' } else { 'absent' }
    $display['Configuration'] = $configurationState
    $display['Environment root'] = $environmentRootState

    return [pscustomobject]@{
        Display  = $display
        Warnings = @($warnings)
    }
}
