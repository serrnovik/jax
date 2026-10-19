function Update-Jax {
    <#
    .SYNOPSIS
        Update the installed Jax to the latest PowerShell Gallery release.
    .DESCRIPTION
        Install-Jax.ps1 copies a source checkout into ~/.jax/module. `jax update`
        is the other half: it replaces whatever is in ~/.jax/module with the
        published package, whether that copy came from the Gallery or was built
        from a checkout.

        It installs into ~/.jax/module rather than leaving the package on
        PSModulePath because that is the only copy the `jx`/`jax` shims load -
        shell/Jax.ShellLauncher.ps1 imports it by path. An `Install-PSResource Jax`
        that lands elsewhere updates a copy none of them ever run, which is the
        trap this command exists to close.

        The downloaded package installs itself by running its own Install-Jax.ps1,
        so staging, backup, symlink rejection, manifest validation, and shell
        integration all come from the release being installed rather than from a
        second implementation here. Releases published before that file shipped
        fall back to a staged directory swap, so `jax update` still works against
        them.

        A local build newer than the Gallery is normal while working on Jax, and
        is reported as current rather than as a problem.
    .PARAMETER RuntimeRoot
        The running Jax runtime root. Defaults to the module's own location.
    .PARAMETER InstallRoot
        Where the managed install lives. Defaults to ~/.jax/module - the only copy
        the jx/jax shims load. Overridable so this can be exercised against a
        fixture directory instead of the caller's real install.
    .PARAMETER Check
        Report versions and exit without changing anything.
    .PARAMETER Yes
        Skip the confirmation prompt.
    .PARAMETER Force
        Reinstall even when the installed version already matches, and bypass the
        24h version cache.
    .EXAMPLE
        jax update --check
        Show where Jax is installed from and whether it is current.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $RuntimeRoot,
        [string] $InstallRoot,
        [switch] $Check,
        [switch] $Yes,
        [switch] $Force
    )

    if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) {
        $RuntimeRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    }
    if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
        $InstallRoot = Join-Path $HOME '.jax/module'
    }
    $installRoot = [IO.Path]::GetFullPath($InstallRoot)

    $info = Get-JaxInstallInfo -RuntimeRoot $RuntimeRoot -IncludeGalleryCopies
    # Bound to this runtime rather than resolved by bare name - see
    # Get-JaxGalleryStatus for why that distinction matters here of all places.
    $status = Get-JaxGalleryStatus -RuntimeRoot $RuntimeRoot -Force:$Force

    # The version that matters is the one in ~/.jax/module - the copy the shims
    # load - not the checkout this command may be running from.
    $installed = if ($info.RuntimeRoot -eq $installRoot) { $info } else { Get-JaxInstallInfo -RuntimeRoot $installRoot }
    $installedPresent = Test-Path -LiteralPath (Join-Path $installRoot 'Jax.psd1') -PathType Leaf

    Write-Host ''
    Write-Host '  jax update' -ForegroundColor Cyan
    if ($installedPresent) {
        $originLabel = if ($installed.Flavour -eq 'Gallery') { 'PowerShell Gallery' } else { 'local checkout' }
        Write-Host ("    Installed:  {0}  [{1}]" -f ($installed.Version ?? 'unknown'), $originLabel)
        Write-Host ("    Location:   {0}" -f $installRoot) -ForegroundColor DarkGray
    } else {
        Write-Host '    Installed:  not installed globally' -ForegroundColor Yellow
    }

    if ($null -eq $status -or $status.Status -ne 'Available' -or $null -eq $status.LatestVersion) {
        Write-Host '    Gallery:    unreachable - try again when online.' -ForegroundColor Yellow
        Write-Host ''
        return
    }
    Write-Host ("    Gallery:    {0}" -f $status.LatestVersion)

    if ($info.Flavour -eq 'Repo') {
        Write-Host ("    Running from a checkout at {0}" -f $info.RuntimeRoot) -ForegroundColor DarkGray
    }

    Write-JaxShadowWarning -Info $info -Yes:$Yes -Check:$Check

    $current = $installed.Version
    if ($installedPresent -and $null -ne $current -and $status.LatestVersion -le $current -and -not $Force) {
        # Equal, or a local build ahead of the Gallery. Neither is a problem, so
        # neither gets a warning.
        if ($status.LatestVersion -lt $current) {
            Write-Host ("    {0} is newer than the published {1} - nothing to do." -f $current, $status.LatestVersion) -ForegroundColor Green
        } else {
            Write-Host '    Up to date.' -ForegroundColor Green
        }
        Write-Host ''
        return
    }

    if ($Check) {
        Write-Host ("    Update available: {0} -> {1}   (run: jax update)" -f ($current ?? 'none'), $status.LatestVersion) -ForegroundColor Cyan
        Write-Host ''
        return
    }

    Write-Host ''
    if ($installedPresent -and $installed.Flavour -eq 'Manual') {
        Write-Host '  The installed copy was built from a checkout.' -ForegroundColor Yellow
        Write-Host '  Updating replaces it with the published Gallery package.' -ForegroundColor DarkGray
        Write-Host '  To keep tracking your checkout instead, run ./Install-Jax.ps1 from it.' -ForegroundColor DarkGray
    }

    if (-not $Yes) {
        $prompt = "  Install Jax $($status.LatestVersion) from the PowerShell Gallery into ${installRoot}? [y/N]"
        if ((Read-Host $prompt) -notin @('y', 'Y', 'yes')) {
            Write-Host '  Cancelled.' -ForegroundColor DarkGray
            Write-Host ''
            return
        }
    }

    if (-not $PSCmdlet.ShouldProcess($installRoot, "Install Jax $($status.LatestVersion) from the PowerShell Gallery")) {
        return
    }

    $staged = Save-JaxGalleryPackage -Version $status.LatestVersion
    if (-not $staged) {
        Write-Host ''
        return
    }

    try {
        if (Install-JaxStagedPackage -StagedRoot $staged -InstallRoot $installRoot) {
            Write-Host ("  Jax {0} installed to {1}" -f $status.LatestVersion, $installRoot) -ForegroundColor Green
            Write-JaxSessionReload -InstallRoot $installRoot
        }
    } finally {
        Remove-Item -LiteralPath (Split-Path -Parent $staged) -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host ''
}
