function Write-JaxShortcutFile {
    <#
    .SYNOPSIS
        Write only the shortcuts map to .jax/jax.shortcut.yml (does not touch jax.config.yml).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Shortcuts,
        [Parameter(Mandatory = $true)]
        [hashtable] $CommonParams
    )

    if ($null -eq $Shortcuts) { $Shortcuts = @{} }

    $base = Get-JaxDefaultConfig
    $base['shortcuts'] = $Shortcuts
    $saved = Convert-JaxConfigForSave -Config $base
    $payload = @{ jax = [ordered]@{ shortcuts = $saved['shortcuts'] } }

    $dir = Split-Path -Path $Path -Parent
    if (-not (Test-Path -Path $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Write-JaxYaml -Path $Path -InputObject $payload @CommonParams
}
