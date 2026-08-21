function Save-JaxGalleryPackage {
    <#
    .SYNOPSIS
        Download a Jax release from the PowerShell Gallery into a temp directory.
    .DESCRIPTION
        Returns the directory that actually contains Jax.psd1, or $null when the
        download fails. Save-PSResource and Save-Module lay a package out
        differently (flat versus a version subdirectory), so the module root is
        found by looking for the manifest rather than by assuming a shape.

        Nothing is written straight into ~/.jax/module: a half-downloaded module
        directory is worse than an old one.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [version] $Version,

        [string] $Repository = 'PSGallery'
    )

    $stagingParent = Join-Path ([IO.Path]::GetTempPath()) ('jax-update-{0}' -f [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stagingParent -Force | Out-Null

    Write-Host ("  Downloading Jax {0} from the {1}..." -f $Version, $Repository) -ForegroundColor Cyan
    $saved = $false
    try {
        if (Get-Command Save-PSResource -ErrorAction SilentlyContinue) {
            Save-PSResource -Name 'Jax' -Version $Version.ToString() -Repository $Repository `
                -Path $stagingParent -TrustRepository -ErrorAction Stop
            $saved = $true
        } elseif (Get-Command Save-Module -ErrorAction SilentlyContinue) {
            Save-Module -Name 'Jax' -RequiredVersion $Version.ToString() -Repository $Repository `
                -Path $stagingParent -Force -ErrorAction Stop
            $saved = $true
        } else {
            Write-Host '  Neither Save-PSResource nor Save-Module is available.' -ForegroundColor Red
            Write-Host '  Install Microsoft.PowerShell.PSResourceGet, or update from a checkout with ./Install-Jax.ps1.' -ForegroundColor DarkGray
        }
    } catch {
        Write-Host ("  Download failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }

    if ($saved) {
        $manifest = Get-ChildItem -LiteralPath $stagingParent -Filter 'Jax.psd1' -Recurse -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($manifest) {
            return $manifest.Directory.FullName
        }
        Write-Host '  The downloaded package did not contain Jax.psd1.' -ForegroundColor Red
    }

    Remove-Item -LiteralPath $stagingParent -Recurse -Force -ErrorAction SilentlyContinue
    return $null
}

function Install-JaxStagedPackage {
    <#
    .SYNOPSIS
        Install a downloaded Jax package into the install root.
    .DESCRIPTION
        Preferred path: run the package's own Install-Jax.ps1, so staging, backup,
        symlink rejection, manifest validation, and shell integration all come from
        the release being installed rather than from a second implementation here.

        It runs in a child pwsh because the installer removes and re-imports the
        Jax module as its last step, and doing that inside the `jax update` that is
        still executing would pull the running command's own module out from under
        it.

        Fallback: releases published before Install-Jax.ps1 shipped in the package
        get a plain staged directory swap - move the old install aside, copy the
        new one in, put the old one back if that fails - so `jax update` still
        works against them.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $StagedRoot,

        [Parameter(Mandatory)]
        [string] $InstallRoot
    )

    $installer = Join-Path $StagedRoot 'Install-Jax.ps1'
    if (Test-Path -LiteralPath $installer -PathType Leaf) {
        $pwshPath = [Environment]::ProcessPath
        if ([string]::IsNullOrWhiteSpace($pwshPath)) { $pwshPath = 'pwsh' }
        & $pwshPath -NoLogo -NoProfile -File $installer -InstallRoot $InstallRoot
        if ($LASTEXITCODE -eq 0) { return $true }
        Write-Host ("  The package installer exited with code {0}." -f $LASTEXITCODE) -ForegroundColor Red
        return $false
    }

    Write-Host '  This release predates the packaged installer - falling back to a direct swap.' -ForegroundColor DarkGray
    return Copy-JaxStagedPackage -StagedRoot $StagedRoot -InstallRoot $InstallRoot
}

function Copy-JaxStagedPackage {
    <#
    .SYNOPSIS
        Swap a staged package directory into the install root.
    .DESCRIPTION
        The old install is moved aside first and put back if the copy fails, so an
        interrupted update cannot leave the user with no Jax at all. ~/.jax/shell
        is refreshed too: the zsh and bash wrappers live there rather than in the
        module directory, and a wrapper that has drifted from the module it loads
        fails in ways that look nothing like "the update half-finished".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $StagedRoot,

        [Parameter(Mandatory)]
        [string] $InstallRoot
    )

    $parent = Split-Path -Parent $InstallRoot
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $backup = Join-Path $parent ('.jax-backup-{0}' -f [guid]::NewGuid().ToString('N'))
    $hadPrevious = Test-Path -LiteralPath $InstallRoot

    try {
        if ($hadPrevious) {
            Move-Item -LiteralPath $InstallRoot -Destination $backup -Force -ErrorAction Stop
        }
        Copy-Item -LiteralPath $StagedRoot -Destination $InstallRoot -Recurse -Force -ErrorAction Stop

        $shellSource = Join-Path $InstallRoot 'shell'
        if (Test-Path -LiteralPath $shellSource -PathType Container) {
            $shellDest = Join-Path $parent 'shell'
            if (Test-Path -LiteralPath $shellDest) {
                Remove-Item -LiteralPath $shellDest -Recurse -Force -ErrorAction SilentlyContinue
            }
            Copy-Item -LiteralPath $shellSource -Destination $shellDest -Recurse -Force -ErrorAction SilentlyContinue
        }

        if ($hadPrevious) {
            Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue
        }
        return $true
    } catch {
        Write-Host ("  Install failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        if ($hadPrevious -and (Test-Path -LiteralPath $backup)) {
            if (Test-Path -LiteralPath $InstallRoot) {
                Remove-Item -LiteralPath $InstallRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
            Move-Item -LiteralPath $backup -Destination $InstallRoot -Force -ErrorAction SilentlyContinue
            Write-Host '  Previous install restored.' -ForegroundColor Yellow
        }
        return $false
    }
}

function Write-JaxShadowWarning {
    <#
    .SYNOPSIS
        Report Jax copies on PSModulePath that a bare Import-Module would pick over
        the one Jax actually runs, and offer to remove them.
    .DESCRIPTION
        Install-Jax.ps1 and `jax update` both target ~/.jax/module, which is not on
        PSModulePath. A leftover `Install-Module Jax` therefore keeps answering
        `Import-Module Jax` - including from scripts, plugins, and other modules -
        with a version nobody is maintaining. Silent until such a copy exists and
        its version differs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Info,

        [switch] $Yes,

        [switch] $Check
    )

    if (-not $Info.ShadowedBy) { return }

    Write-Host ''
    Write-Host '  Another Jax is installed on PSModulePath:' -ForegroundColor Yellow
    foreach ($copy in $Info.GalleryCopies) {
        Write-Host ("    {0}  {1}" -f $copy.Version, $copy.Path) -ForegroundColor DarkGray
    }
    Write-Host '  `Import-Module Jax` resolves to that copy, not the one your shell runs.' -ForegroundColor DarkGray

    if ($Check) { return }

    $remove = [bool]$Yes
    if (-not $remove) {
        $remove = (Read-Host '  Remove the PSModulePath copies? [y/N]') -in @('y', 'Y', 'yes')
    }
    if (-not $remove) { return }

    foreach ($copy in $Info.GalleryCopies) {
        try {
            # Uninstall-PSResource cleans the PSResourceGet bookkeeping as well as
            # the directory; a plain delete leaves the install registered.
            if (Get-Command Uninstall-PSResource -ErrorAction SilentlyContinue) {
                Uninstall-PSResource -Name 'Jax' -Version $copy.Version.ToString() -SkipDependencyCheck -ErrorAction Stop
            } else {
                Remove-Item -LiteralPath $copy.Path -Recurse -Force -ErrorAction Stop
            }
            Write-Host ("    removed {0}" -f $copy.Path) -ForegroundColor Green
        } catch {
            Write-Host ("    could not remove {0}: {1}" -f $copy.Path, $_.Exception.Message) -ForegroundColor Red
        }
    }
}
