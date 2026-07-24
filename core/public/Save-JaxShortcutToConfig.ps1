function Save-JaxShortcutToConfig {
    <#
    .SYNOPSIS
        Persist a shortcut name and its argument list into .jax/jax.shortcut.yml (jax.config.yml is not rewritten).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [hashtable] $CommonParams,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]] $ArgsToSave,
        [string] $RepoRoot
    )

    # Coerce in case a caller passed a string (e.g. unwrapped single element from another function)
    if ($null -ne $ArgsToSave -and $ArgsToSave -isnot [string[]]) {
        if ($ArgsToSave -is [string]) {
            if ([string]::IsNullOrWhiteSpace([string]$ArgsToSave)) {
                $ArgsToSave = @()
            } else {
                $ArgsToSave = @([string]$ArgsToSave)
            }
        } else {
            $ArgsToSave = [string[]]@($ArgsToSave)
        }
    }
    if ($null -eq $ArgsToSave) { $ArgsToSave = @() }

    $repoRoot = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { Get-JaxRepoRoot @CommonParams } else { $RepoRoot }
    $shortcutPath = Get-JaxRepoShortcutFilePath -RepoRoot $repoRoot @CommonParams
    $cfg = Get-JaxConfig -RepoRoot $repoRoot @CommonParams

    if (-not ($cfg.Contains('shortcuts')) -or $cfg['shortcuts'] -isnot [System.Collections.IDictionary]) {
        $cfg['shortcuts'] = @{}
    }
    $cfg['shortcuts'][$Name] = $ArgsToSave

    Write-JaxShortcutFile -Path $shortcutPath -Shortcuts $cfg['shortcuts'] -CommonParams $CommonParams
    Write-Host "✅ Saved shortcut '$Name': $($ArgsToSave -join ' ')"
    Write-Host "   (stored in .jax/jax.shortcut.yml; jax.config.yml unchanged)"
    Write-Host "   Run with: jx -sc $Name"
}
