function Get-JaxInstallInfo {
    <#
    .SYNOPSIS
        Describe how the running copy of Jax got onto this machine.
    .DESCRIPTION
        Jax can be loaded three ways, and the right way to update it differs for
        each one:

          Repo    - run straight from a source checkout. Updating means `git pull`.
          Manual  - installed into ~/.jax/module by Install-Jax.ps1 from a
                    checkout. Update-PSResource does not touch this copy at all,
                    because PSResourceGet never installed it.
          Gallery - the published package, either installed into ~/.jax/module by
                    `jax update` or sitting under a PSModulePath entry.

        Telling a manual install to run `Update-PSResource Jax` is the failure this
        exists to prevent: it either errors or updates a different copy that the
        `jx` shim never loads, because the shim resolves ~/.jax/module through
        shell/Jax.ShellLauncher.ps1 rather than through PSModulePath.

        Origin comes from INSTALLATION.json: Build-JaxPackage stamps 'Gallery' and
        Install-Jax.ps1 copies that forward. Records written before Origin existed
        report Manual, which is what they are.
    .PARAMETER RuntimeRoot
        The Jax runtime being described - the directory holding Jax.psd1.
    .PARAMETER IncludeGalleryCopies
        Also enumerate Jax modules on PSModulePath and work out whether one shadows
        the loaded copy for a bare `Import-Module Jax`. Off by default because
        enumerating PSModulePath is far too slow for the per-run update notice.
    .EXAMPLE
        Get-JaxInstallInfo -RuntimeRoot $PSScriptRoot -IncludeGalleryCopies
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RuntimeRoot,

        [string] $InstallRoot = (Join-Path $HOME '.jax/module'),

        [switch] $IncludeGalleryCopies
    )

    $resolvedRoot = try { [IO.Path]::GetFullPath($RuntimeRoot) } catch { $RuntimeRoot }
    $resolvedInstall = try { [IO.Path]::GetFullPath($InstallRoot) } catch { $InstallRoot }

    $version = $null
    $manifestPath = Join-Path $resolvedRoot 'Jax.psd1'
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        try {
            $parsed = $null
            $text = [string](Import-PowerShellDataFile -LiteralPath $manifestPath).ModuleVersion
            if ([version]::TryParse($text, [ref] $parsed)) { $version = $parsed }
        } catch {
            # An unreadable manifest is an unknown version, not a failed command.
        }
    }

    $record = Read-JaxJsonFile -Path (Join-Path $resolvedRoot 'INSTALLATION.json')
    $origin = [string](Get-JaxJsonProperty -Object $record -Name 'Origin')

    $flavour = if ($resolvedRoot -eq $resolvedInstall) {
        if ($origin -in @('Gallery', 'Manual')) { $origin } else { 'Manual' }
    } elseif (Test-JaxPathUnderModulePath -Path $resolvedRoot) {
        'Gallery'
    } else {
        'Repo'
    }

    $galleryCopies = @()
    $shadowedBy = $null
    if ($IncludeGalleryCopies) {
        try {
            $galleryCopies = @(
                Get-Module -ListAvailable -Name 'Jax' -ErrorAction SilentlyContinue |
                    Where-Object { [IO.Path]::GetFullPath($_.ModuleBase) -ne $resolvedRoot } |
                    Sort-Object Version -Descending |
                    ForEach-Object { [pscustomobject]@{ Version = $_.Version; Path = $_.ModuleBase } }
            )
        } catch {
            $galleryCopies = @()
        }
        $shadowedBy = @($galleryCopies | Where-Object { $null -eq $version -or $_.Version -ne $version }) |
            Select-Object -First 1
    }

    [pscustomobject]@{
        Flavour        = $flavour
        RuntimeRoot    = $resolvedRoot
        InstallRoot    = $resolvedInstall
        Version        = $version
        SourceCommit   = [string](Get-JaxJsonProperty -Object $record -Name 'SourceCommit')
        InstalledAtUtc = ConvertTo-JaxUtcDate -Value (Get-JaxJsonProperty -Object $record -Name 'InstalledAtUtc')
        GalleryCopies  = $galleryCopies
        ShadowedBy     = $shadowedBy
        UpdateCommand  = if ($flavour -eq 'Repo') { 'git pull, then ./Install-Jax.ps1' } else { 'jax update' }
    }
}

function Test-JaxPathUnderModulePath {
    <#
    .SYNOPSIS
        True when Path sits inside one of the PSModulePath roots.
    .DESCRIPTION
        Distinguishes an Install-Module copy from a checkout. Compared as
        normalised path prefixes so a trailing separator or a relative
        PSModulePath entry does not produce a false negative.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $target = try { [IO.Path]::GetFullPath($Path) } catch { return $false }
    $separator = [IO.Path]::DirectorySeparatorChar

    foreach ($entry in @([string]$env:PSModulePath -split [IO.Path]::PathSeparator)) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        $root = try { [IO.Path]::GetFullPath($entry) } catch { continue }
        $prefix = $root.TrimEnd($separator, [IO.Path]::AltDirectorySeparatorChar) + $separator
        if ($target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }

    return $false
}
