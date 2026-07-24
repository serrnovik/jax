function Initialize-JaxPlaceholdersProvider {
    [CmdletBinding()]
    param ()

    $command = Get-Command -Name Expand-JaxMPPlaceholders -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return
    }

    $modulePath = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'MustachePlaceholders' 'MustachePlaceholders.psm1')
    Import-Module $modulePath -DisableNameChecking -Prefix JaxMP -Force -ErrorAction Stop | Out-Null

    $command = Get-Command -Name Expand-JaxMPPlaceholders -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "Jax placeholders provider did not register Expand-JaxMPPlaceholders."
    }
}
