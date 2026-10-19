function Write-JaxSessionReload {
    <#
    .SYNOPSIS
        Load a freshly installed Jax into the calling PowerShell session.
    .DESCRIPTION
        The jx/jax shell shims start a new pwsh per command, so they pick up the
        new install on their next run. Inside an interactive pwsh the module is
        already imported, and its jax/jx/jxs aliases keep pointing at the old
        copy until it is imported again. Re-import it globally so the new
        version is live in this console without a restart.
    .PARAMETER InstallRoot
        Directory holding the installed Jax.psd1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $InstallRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($env:JAX_SHELL_ENTRYPOINT)) {
        Write-Host '  The next jx command uses it.' -ForegroundColor DarkGray
        return
    }

    $manifest = Join-Path $InstallRoot 'Jax.psd1'
    try {
        Get-Module Jax | Remove-Module -Force -ErrorAction SilentlyContinue
        $loaded = Import-Module $manifest -Global -Force -DisableNameChecking -PassThru -ErrorAction Stop |
            Select-Object -First 1
        Write-Host ("  Loaded Jax {0} into this session." -f $loaded.Version) -ForegroundColor DarkGray
    } catch {
        Write-Host ("  Could not load it into this session ({0}). Restart your terminal." -f $_.Exception.Message) -ForegroundColor Yellow
    }
}
