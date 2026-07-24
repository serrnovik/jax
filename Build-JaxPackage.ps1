#!/usr/bin/env pwsh
[CmdletBinding()]
param (
    [string] $OutputPath = (Join-Path $PSScriptRoot '.artifacts/Jax'),
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$outputRoot = [IO.Path]::GetFullPath($OutputPath)
$protectedRoots = @(
    [IO.Path]::GetFullPath([IO.Path]::GetPathRoot($outputRoot))
    [IO.Path]::GetFullPath($HOME)
    $sourceRoot
)
if ($protectedRoots -contains $outputRoot) {
    throw "Refusing unsafe package output path: $outputRoot"
}
$sourceRelativeToOutput = [IO.Path]::GetRelativePath($outputRoot, $sourceRoot)
if (-not [IO.Path]::IsPathRooted($sourceRelativeToOutput) -and
    $sourceRelativeToOutput -ne '..' -and
    -not $sourceRelativeToOutput.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)) {
    throw "Refusing package output path that contains the source checkout: $outputRoot"
}

$manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $sourceRoot 'distribution-manifest.psd1')
$moduleManifest = Import-PowerShellDataFile -LiteralPath (Join-Path $sourceRoot 'Jax.psd1')
$version = (Get-Content -LiteralPath (Join-Path $sourceRoot 'VERSION') -Raw).Trim()
if ($version -ne [string]$manifest.Version -or $version -ne [string]$moduleManifest.ModuleVersion) {
    throw 'VERSION, distribution-manifest.psd1, and Jax.psd1 must contain the same version.'
}

if (Test-Path -LiteralPath $outputRoot) {
    $outputItem = Get-Item -LiteralPath $outputRoot -Force
    if ($outputItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Refusing package output path that is a symbolic link or reparse point: $outputRoot"
    }
    if (-not $Force) {
        throw "Package output already exists: $outputRoot (use -Force to replace it)."
    }
    foreach ($marker in @('Jax.psd1', 'Jax.psm1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $outputRoot $marker) -PathType Leaf)) {
            throw "Refusing to replace a directory that is not a Jax package: $outputRoot"
        }
    }
}

$outputParent = Split-Path -Parent $outputRoot
New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
$stagingRoot = Join-Path $outputParent ('.jax-package-staging-' + [guid]::NewGuid().ToString('N'))

function Test-JaxPackagePathWithin {
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

function Assert-JaxPackageSourceSafe {
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

function Copy-JaxPackageEntry {
    param(
        [Parameter(Mandatory)] [string] $RelativePath
    )

    $source = [IO.Path]::GetFullPath((Join-Path $sourceRoot $RelativePath))
    $destination = [IO.Path]::GetFullPath((Join-Path $stagingRoot $RelativePath))
    if (-not (Test-JaxPackagePathWithin -Parent $sourceRoot -Candidate $source)) {
        throw "Distribution manifest entry escapes the Jax source root: $RelativePath"
    }
    if (-not (Test-JaxPackagePathWithin -Parent $stagingRoot -Candidate $destination)) {
        throw "Distribution manifest destination escapes the package staging root: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Distribution manifest entry is missing: $RelativePath"
    }
    Assert-JaxPackageSourceSafe -Path $source
    $destinationParent = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
}

try {
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
    foreach ($file in @($manifest.Files)) {
        Copy-JaxPackageEntry -RelativePath ([string]$file)
    }
    foreach ($directory in @($manifest.Directories)) {
        Copy-JaxPackageEntry -RelativePath ([string]$directory)
    }
    foreach ($set in @($manifest.DirectorySets)) {
        foreach ($entry in @($set.Entries)) {
            Copy-JaxPackageEntry -RelativePath (Join-Path ([string]$set.Target) ([string]$entry))
        }
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
    [ordered]@{
        Version        = $version
        SourceCommit   = $sourceCommit
        InstalledAtUtc = [DateTime]::UtcNow.ToString('O')
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stagingRoot 'INSTALLATION.json') -Encoding utf8

    Test-ModuleManifest -Path (Join-Path $stagingRoot 'Jax.psd1') -ErrorAction Stop | Out-Null
    if (Test-Path -LiteralPath $outputRoot) {
        Remove-Item -LiteralPath $outputRoot -Recurse -Force
    }
    Move-Item -LiteralPath $stagingRoot -Destination $outputRoot
} finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}

Write-Host "Jax $version package staged at $outputRoot" -ForegroundColor Green
return $outputRoot
