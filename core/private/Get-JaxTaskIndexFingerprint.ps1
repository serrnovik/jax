function Get-JaxTaskIndexFingerprint {
    <#
    .SYNOPSIS
    Fingerprint of everything that can change task names, or $null outside git.

    .DESCRIPTION
    HEAD plus every changed or untracked .ps1/.psm1/.yml/.yaml file with its
    write time and size, plus the Jax version. Task names come from psake files
    and YAML configs, so edits to other files keep the index valid. A file
    edited twice keeps the same git status, which is why write time is included.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot
    )

    if (-not (Get-Command -Name git -ErrorAction SilentlyContinue)) {
        return $null
    }
    $head = & git -C $RepoRoot rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($head)) {
        return $null
    }
    # Porcelain paths are relative to the top level, and a RepoRoot below it
    # (a nested Jax repository) must still see changes anywhere in the repo:
    # includes and task paths may point outside RepoRoot.
    $topLevel = & git -C $RepoRoot rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($topLevel)) {
        return $null
    }
    $status = & git -C $topLevel status --porcelain=v1 --untracked-files=all -- '*.ps1' '*.psm1' '*.yml' '*.yaml' 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $parts = [System.Collections.Generic.List[string]]::new()
    $parts.Add([string]$head)
    $parts.Add($RepoRoot)
    # Discovery itself: a Jax update or an edited Jax checkout changes the index.
    $toolRoot = Get-JaxToolRoot
    $versionFile = Join-Path $toolRoot 'VERSION'
    if (Test-Path -LiteralPath $versionFile -PathType Leaf) {
        $parts.Add((Get-Content -LiteralPath $versionFile -Raw).Trim())
    }
    $toolFiles = @(Get-ChildItem -LiteralPath (Join-Path $toolRoot 'core'), (Join-Path $toolRoot 'plugins') -Recurse -File -Filter '*.ps*1' -ErrorAction SilentlyContinue)
    if ($toolFiles.Count -gt 0) {
        $parts.Add([string]($toolFiles | Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum.Ticks)
    }
    foreach ($line in @($status | Sort-Object)) {
        $path = ([string]$line).Substring(3).Trim('"')
        if ($path -match ' -> ') { $path = ($path -split ' -> ')[-1].Trim('"') }
        $full = Join-Path $topLevel $path
        $stamp = 'missing'
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $item = Get-Item -LiteralPath $full
            $stamp = '{0}|{1}' -f $item.LastWriteTimeUtc.Ticks, $item.Length
        }
        $parts.Add("$line|$stamp")
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
    return [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
}
