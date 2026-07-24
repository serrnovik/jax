function Remove-JaxShortcutFromConfig {
    <#
    .SYNOPSIS
        Remove a saved shortcut from .jax/jax.shortcut.yml (or drop it if it only existed in jax.config; jax.config.yml is not rewritten).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [hashtable] $CommonParams,
        [string] $RepoRoot
    )

    $repoRoot = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { Get-JaxRepoRoot @CommonParams } else { $RepoRoot }
    $shortcutPath = Get-JaxRepoShortcutFilePath -RepoRoot $repoRoot @CommonParams
    $cfg = Get-JaxConfig -RepoRoot $repoRoot @CommonParams

    if (-not ($cfg.Contains('shortcuts')) -or $cfg['shortcuts'] -isnot [System.Collections.IDictionary]) {
        $cfg['shortcuts'] = @{}
    }
    $shortcuts = $cfg['shortcuts']
    if (-not $shortcuts.Contains($Name)) {
        $available = @($shortcuts.Keys | Sort-Object) -join ', '
        if ([string]::IsNullOrWhiteSpace($available)) { $available = '(none)' }
        throw "Shortcut '$Name' not found in saved shortcuts. Available: $available"
    }
    $null = $shortcuts.Remove($Name)

    Write-JaxShortcutFile -Path $shortcutPath -Shortcuts $shortcuts -CommonParams $CommonParams
    Write-Host "✅ Removed shortcut '$Name' (saved in .jax/jax.shortcut.yml)"
}
