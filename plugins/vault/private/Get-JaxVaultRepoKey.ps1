function Get-JaxVaultRepoKey {
    <#
    .SYNOPSIS
    Returns a stable per-repository key for the default Vault token directory.

    .DESCRIPTION
    Uses the origin remote name, then the main checkout folder name (so all
    worktrees of one repository share a key), then the repository folder name.
    The result only contains lowercase letters, digits, '.', '_' and '-'.
    #>
    [CmdletBinding()]
    param(
        [string] $RepoRoot = (Get-JaxRepoRoot)
    )

    $candidates = New-Object System.Collections.Generic.List[string]
    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($git -and -not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        try {
            $origin = & $git.Source -C $RepoRoot remote get-url origin 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$origin)) {
                $name = ([string]$origin).Trim().TrimEnd('/') -replace '\.git$', ''
                $candidates.Add(($name -split '[/:\\]')[-1]) | Out-Null
            }
        } catch {}
        try {
            $commonDir = & $git.Source -C $RepoRoot rev-parse --path-format=absolute --git-common-dir 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$commonDir)) {
                $candidates.Add((Split-Path -Leaf (Split-Path -Parent ([string]$commonDir).Trim()))) | Out-Null
            }
        } catch {}
    }
    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        $candidates.Add((Split-Path -Leaf $RepoRoot.TrimEnd('/', '\'))) | Out-Null
    }

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $key = ($candidate.ToLowerInvariant() -replace '[^a-z0-9._-]', '-').Trim('-', '.')
        if (-not [string]::IsNullOrWhiteSpace($key) -and $key -ne 'vault') {
            return $key
        }
    }
    return 'default'
}
