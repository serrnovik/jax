[CmdletBinding()]
param (
    [string] $InstallRoot = (Join-Path $HOME '.jax/module'),
    [switch] $SkipProfile,
    [string] $ProfilePath = $PROFILE.CurrentUserCurrentHost,
    [string[]] $Shell
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$validShells = @('powershell', 'zsh', 'bash')
$normalizedShells = @(
    foreach ($shellValue in @($Shell)) {
        foreach ($shellName in @([string]$shellValue -split ',')) {
            $normalizedShell = $shellName.Trim().ToLowerInvariant()
            if ([string]::IsNullOrWhiteSpace($normalizedShell)) {
                continue
            }
            if ($normalizedShell -notin $validShells) {
                throw "Unsupported Jax shell '$normalizedShell'. Expected one of: $($validShells -join ', ')."
            }
            $normalizedShell
        }
    }
)
$Shell = @($normalizedShells | Select-Object -Unique)

$sourceRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$installRootResolved = [IO.Path]::GetFullPath($InstallRoot)
$pathRoot = [IO.Path]::GetFullPath([IO.Path]::GetPathRoot($installRootResolved))
$homeRoot = [IO.Path]::GetFullPath($HOME)
$jaxHome = [IO.Path]::GetFullPath((Join-Path $HOME '.jax'))
$protectedRoots = @($pathRoot, $homeRoot, $jaxHome)
if ($protectedRoots -contains $installRootResolved) {
    throw "Refusing unsafe install root: $installRootResolved"
}
$sourcePrefix = $sourceRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$installPrefix = $installRootResolved.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if ($sourcePrefix.StartsWith($installPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to install over a parent of the source checkout: $installRootResolved"
}
if ($sourceRoot -eq $installRootResolved) {
    throw 'Run Install-Jax.ps1 from a source checkout, not from the installed module directory.'
}
if (-not $SkipProfile) {
    if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
        throw 'PowerShell profile path cannot be empty unless -SkipProfile is supplied.'
    }
    $ProfilePath = [IO.Path]::GetFullPath($ProfilePath)
    if (Test-Path -LiteralPath $ProfilePath -PathType Container) {
        throw "PowerShell profile path points to a directory: $ProfilePath"
    }
}

$manifestPath = Join-Path $sourceRoot 'distribution-manifest.psd1'
$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
if ([string]::IsNullOrWhiteSpace([string]$manifest.Version)) {
    throw "Distribution manifest '$manifestPath' has no version."
}

$requiredYamlVersion = [version]'0.4.12'
$yamlModule = Get-Module -ListAvailable -Name powershell-yaml -ErrorAction SilentlyContinue |
    Where-Object { $_.Version -eq $requiredYamlVersion } |
    Select-Object -First 1
if ($null -eq $yamlModule) {
    $installModuleCommand = Get-Command -Name Install-Module -ErrorAction SilentlyContinue
    if ($null -eq $installModuleCommand) {
        throw @"
Jax requires powershell-yaml $requiredYamlVersion, but Install-Module is unavailable.
Install that dependency from a trusted PowerShell repository, then run this installer again.
"@
    }

    Write-Host "Installing dependency powershell-yaml $requiredYamlVersion for CurrentUser..." -ForegroundColor Cyan
    Install-Module -Name powershell-yaml -Repository PSGallery -Scope CurrentUser `
        -RequiredVersion $requiredYamlVersion -Force -AllowClobber -ErrorAction Stop
}

$sourceCommit = 'unknown'
if (Get-Command -Name git -ErrorAction SilentlyContinue) {
    try {
        $resolvedCommit = & git -C $sourceRoot rev-parse HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($resolvedCommit)) {
            $sourceCommit = $resolvedCommit.Trim()
        }
    } catch {
    }
}

$installParent = Split-Path -Parent $installRootResolved
if (-not (Test-Path -LiteralPath $installParent -PathType Container)) {
    New-Item -ItemType Directory -Path $installParent -Force | Out-Null
}
if (Test-Path -LiteralPath $installRootResolved) {
    $requiredInstallMarkers = @('Jax.psd1', 'Jax.psm1', 'INSTALLATION.json')
    $missingInstallMarkers = @($requiredInstallMarkers | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $installRootResolved $_) -PathType Leaf)
    })
    if ($missingInstallMarkers.Count -gt 0) {
        throw "Refusing to replace a directory that is not an installed Jax module: $installRootResolved"
    }
}

$stagingRoot = Join-Path $installParent ('.jax-staging-{0}' -f [guid]::NewGuid().ToString('N'))
$backupRoot = Join-Path $installParent ('.jax-backup-{0}' -f [guid]::NewGuid().ToString('N'))

function Test-JaxInstallPathWithin {
    param(
        [Parameter(Mandatory)] [string] $Parent,
        [Parameter(Mandatory)] [string] $Candidate
    )

    $relative = [IO.Path]::GetRelativePath(
        [IO.Path]::GetFullPath($Parent),
        [IO.Path]::GetFullPath($Candidate)
    )
    if ($relative -eq '.') { return $true }
    if ([IO.Path]::IsPathRooted($relative) -or $relative -eq '..') { return $false }
    return -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)
}

function Assert-JaxInstallSourceSafe {
    param([Parameter(Mandatory)] [string] $Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $items = @($item)
    if ($item.PSIsContainer) {
        $items += @(Get-ChildItem -LiteralPath $item.FullName -Force -Recurse -ErrorAction Stop)
    }
    $link = $items | Where-Object {
        ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        -not [string]::IsNullOrWhiteSpace([string]$_.LinkType)
    } | Select-Object -First 1
    if ($null -ne $link) {
        $relative = [IO.Path]::GetRelativePath($sourceRoot, $link.FullName)
        throw "Distribution manifest entry contains a symbolic link or reparse point: $relative"
    }
}

function Copy-JaxManifestEntry {
    param (
        [Parameter(Mandatory = $true)] [string] $Source,
        [Parameter(Mandatory = $true)] [string] $Destination
    )

    $sourceResolved = [IO.Path]::GetFullPath($Source)
    $destinationResolved = [IO.Path]::GetFullPath($Destination)
    if (-not (Test-JaxInstallPathWithin -Parent $sourceRoot -Candidate $sourceResolved)) {
        throw "Distribution manifest entry escapes the Jax source root: $Source"
    }
    if (-not (Test-JaxInstallPathWithin -Parent $stagingRoot -Candidate $destinationResolved)) {
        throw "Distribution manifest destination escapes the install staging root: $Destination"
    }
    if (-not (Test-Path -LiteralPath $sourceResolved)) {
        throw "Distribution manifest entry is missing: $sourceResolved"
    }
    Assert-JaxInstallSourceSafe -Path $sourceResolved
    $destinationParent = Split-Path -Parent $destinationResolved
    if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    }
    Copy-Item -LiteralPath $sourceResolved -Destination $destinationResolved -Recurse -Force
}

try {
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
    foreach ($file in @($manifest.Files)) {
        Copy-JaxManifestEntry -Source (Join-Path $sourceRoot $file) -Destination (Join-Path $stagingRoot $file)
    }
    foreach ($directory in @($manifest.Directories)) {
        Copy-JaxManifestEntry -Source (Join-Path $sourceRoot $directory) -Destination (Join-Path $stagingRoot $directory)
    }
    foreach ($set in @($manifest.DirectorySets)) {
        $targetRoot = Join-Path $stagingRoot ([string]$set.Target)
        New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
        foreach ($entry in @($set.Entries)) {
            $relative = Join-Path ([string]$set.Target) ([string]$entry)
            Copy-JaxManifestEntry -Source (Join-Path $sourceRoot $relative) -Destination (Join-Path $stagingRoot $relative)
        }
    }

    [ordered]@{
        Version       = [string]$manifest.Version
        SourceCommit  = $sourceCommit
        InstalledAtUtc = [DateTime]::UtcNow.ToString('O')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stagingRoot 'INSTALLATION.json') -Encoding utf8

    Test-ModuleManifest -Path (Join-Path $stagingRoot 'Jax.psd1') -ErrorAction Stop | Out-Null

    if (Test-Path -LiteralPath $installRootResolved) {
        Move-Item -LiteralPath $installRootResolved -Destination $backupRoot
    }
    Move-Item -LiteralPath $stagingRoot -Destination $installRootResolved
    if (Test-Path -LiteralPath $backupRoot) {
        Remove-Item -LiteralPath $backupRoot -Recurse -Force
    }
} catch {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
    if ((Test-Path -LiteralPath $backupRoot) -and -not (Test-Path -LiteralPath $installRootResolved)) {
        Move-Item -LiteralPath $backupRoot -Destination $installRootResolved
    }
    throw
}

$installedManifest = Join-Path $installRootResolved 'Jax.psd1'
Get-Module Jax | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module $installedManifest -Global -Force -DisableNameChecking -ErrorAction Stop

if (-not $SkipProfile) {
    $integrationParameters = @{
        ModulePath = $installedManifest
        PowerShellProfilePath = $ProfilePath
    }
    if ($null -ne $Shell -and $Shell.Count -gt 0) {
        $integrationParameters.Shell = $Shell
    }
    Install-JaxShellIntegration @integrationParameters
}

Write-Host ("Jax {0} installed to {1}" -f $manifest.Version, $installRootResolved) -ForegroundColor Green
$escapedInstalledManifest = $installedManifest.Replace("'", "''")
$activateCommand = "Import-Module '$escapedInstalledManifest' -Global -Force -DisableNameChecking"
if ($SkipProfile) {
    Write-Host "Import with: $activateCommand" -ForegroundColor DarkGray
} else {
    Write-Host 'Jax is active now when this script was invoked directly in the current PowerShell.' -ForegroundColor DarkGray
    Write-Host 'New PowerShell and detected or platform-default zsh/bash sessions will load this source installation automatically.' -ForegroundColor DarkGray
    Write-Host 'If this installer was launched through a child `pwsh -File` process, activate its parent with:' -ForegroundColor DarkGray
    Write-Host "  $activateCommand" -ForegroundColor DarkGray
}
