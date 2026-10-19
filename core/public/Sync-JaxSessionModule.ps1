function Sync-JaxSessionModule {
    <#
    .SYNOPSIS
        Reload the Jax module when a newer copy was installed under it.
    .DESCRIPTION
        jax.ps1 and Jax.Core are read from disk on every call, but the Jax module
        (its jax/jx/jxs aliases and completion) stays as it was imported. After
        `jx update` in another terminal, or by an updater that predates the
        automatic reload, this console keeps the old copy until it is imported
        again. Compare the loaded version with the manifest on disk and reload
        when the disk copy is newer. The shell shims start a fresh pwsh per
        command, so they never need this.
    #>
    [CmdletBinding()]
    param()

    if (-not [string]::IsNullOrWhiteSpace($env:JAX_SHELL_ENTRYPOINT)) {
        return
    }

    $loaded = Get-Module Jax | Select-Object -First 1
    if ($null -eq $loaded) {
        return
    }

    $manifest = Join-Path $loaded.ModuleBase 'Jax.psd1'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        return
    }

    $installed = $null
    try {
        $text = [string](Import-PowerShellDataFile -LiteralPath $manifest).ModuleVersion
        if (-not [version]::TryParse($text, [ref] $installed)) {
            return
        }
    } catch {
        return
    }

    if ($installed -le $loaded.Version) {
        return
    }

    Write-Host ("Jax {0} is installed; this session still had {1}." -f $installed, $loaded.Version) -ForegroundColor DarkGray
    Write-JaxSessionReload -InstallRoot $loaded.ModuleBase
}
