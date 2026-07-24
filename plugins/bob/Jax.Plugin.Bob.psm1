Set-StrictMode -Version Latest

$publicPath = Join-Path $PSScriptRoot 'public'
$privatePath = Join-Path $PSScriptRoot 'private'

$public = @()
$private = @()

if (Test-Path -Path $publicPath) {
    $public = @(Get-ChildItem -Path $publicPath -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
}
if (Test-Path -Path $privatePath) {
    $private = @(Get-ChildItem -Path $privatePath -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
}

foreach ($import in @($public + $private)) {
    try {
        . $import.FullName
    } catch {
        throw "Unable to dot source [$($import.FullName)]: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function $public.BaseName

Register-JaxBobPlugin
Register-JaxBobScenarioResolvers
