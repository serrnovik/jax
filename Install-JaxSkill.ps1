[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceRoot = Join-Path $PSScriptRoot 'skills/jax'
$sourceSkill = Join-Path $sourceRoot 'SKILL.md'
if (-not (Test-Path -LiteralPath $sourceSkill -PathType Leaf)) {
    throw "Bundled Jax skill is missing: $sourceSkill"
}

$resolvedRepoRoot = [IO.Path]::GetFullPath($RepoRoot)
$targetRoot = Join-Path $resolvedRepoRoot '.agents/skills/jax'
New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null

foreach ($item in @(Get-ChildItem -LiteralPath $sourceRoot -Force)) {
    Copy-Item -LiteralPath $item.FullName -Destination $targetRoot -Recurse -Force
}

Write-Host "Jax AI-agent skill installed to $targetRoot" -ForegroundColor Green
