[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param (
    [string] $InstallRoot = (Join-Path $HOME '.jax/module'),
    [string] $ProfilePath = $PROFILE.CurrentUserCurrentHost,
    [string] $ZshProfilePath = (Join-Path $HOME '.zshrc'),
    [string] $BashProfilePath = (Join-Path $HOME '.bashrc')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$installRootResolved = [IO.Path]::GetFullPath($InstallRoot)
$pathRoot = [IO.Path]::GetFullPath([IO.Path]::GetPathRoot($installRootResolved))
$protectedRoots = @(
    $pathRoot
    [IO.Path]::GetFullPath($HOME)
    [IO.Path]::GetFullPath((Join-Path $HOME '.jax'))
)
if ($protectedRoots -contains $installRootResolved) {
    throw "Refusing unsafe uninstall root: $installRootResolved"
}
$moduleManifestPath = Join-Path $installRootResolved 'Jax.psd1'
$moduleEntryPath = Join-Path $installRootResolved 'Jax.psm1'
$installationMetadataPath = Join-Path $installRootResolved 'INSTALLATION.json'
if ((Test-Path -LiteralPath $installRootResolved) -and
    (-not (Test-Path -LiteralPath $moduleManifestPath -PathType Leaf) -or
     -not (Test-Path -LiteralPath $moduleEntryPath -PathType Leaf) -or
     -not (Test-Path -LiteralPath $installationMetadataPath -PathType Leaf))) {
    throw "Refusing to remove a directory that is not a Jax installation: $installRootResolved"
}
foreach ($shellProfilePath in @($ProfilePath, $ZshProfilePath, $BashProfilePath) | Select-Object -Unique) {
    if (Test-Path -LiteralPath $shellProfilePath -PathType Leaf) {
        $existing = Get-Content -LiteralPath $shellProfilePath -Raw
        $pattern = '(?ms)^# >>> jax CLI >>>.*?^# <<< jax CLI <<<\r?\n?'
        $updated = [regex]::Replace($existing, $pattern, '').TrimEnd()
        if ($updated -ne $existing -and $PSCmdlet.ShouldProcess($shellProfilePath, 'Remove the Jax profile block')) {
            Set-Content -LiteralPath $shellProfilePath -Value $updated -Encoding utf8
        }
    }
}

if ((Test-Path -LiteralPath $installRootResolved) -and $PSCmdlet.ShouldProcess($installRootResolved, 'Remove the Jax installation')) {
    Remove-Item -LiteralPath $installRootResolved -Recurse -Force
}
