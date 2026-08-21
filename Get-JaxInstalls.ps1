'--- PSGallery-registered ---'
Get-InstalledPSResource -Name Jax -EA SilentlyContinue |
    Select-Object Version, InstalledLocation

'--- On PSModulePath ---'
Get-Module -ListAvailable -Name Jax | Select-Object Version, ModuleBase

'--- Manual install root (~/.jax/module) ---'
if (Test-Path "$HOME\.jax\module\Jax.psd1") {
    [pscustomobject]@{
        Version = (Import-PowerShellDataFile "$HOME\.jax\module\Jax.psd1").ModuleVersion
        Path    = "$HOME\.jax\module"
    }
}

'--- Source checkouts (worktrees) ---'
Get-ChildItem E:\ -Filter Jax.psd1 -Recurse -Force -Depth 6 -EA SilentlyContinue | ForEach-Object {
    [pscustomobject]@{ Version = (Import-PowerShellDataFile $_.FullName).ModuleVersion; Path = $_.DirectoryName }
}

'--- WHICH ONE ACTUALLY RUNS ---'
pwsh -NoLogo -Command 'Get-Module Jax | Select-Object Version, Path'
