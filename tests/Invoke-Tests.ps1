[CmdletBinding()]
param ()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$pester = Get-Module -ListAvailable Pester | Where-Object Version -ge ([version]'5.5.0') | Sort-Object Version -Descending | Select-Object -First 1
if ($null -eq $pester) {
    throw 'Pester 5.5+ is required. Install it with: Install-Module Pester -Scope CurrentUser -MinimumVersion 5.5.0'
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$config = New-PesterConfiguration
$config.Run.Path = @(
    (Join-Path $repoRoot 'tests')
    (Join-Path $repoRoot 'MustachePlaceholders/tests')
)
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $config
if ($result.FailedCount -gt 0) {
    exit 1
}
