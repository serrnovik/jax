function Get-JaxShortcutArgsToSave {
    <#
    .SYNOPSIS
        Build the string[] stored for a jax CLI shortcut (command + core flags + CommandArgs).
    #>
    [CmdletBinding()]
    param(
        [string] $Command,
        [string] $env,
        [string] $client,
        [string] $scenario,
        [AllowNull()]
        $only,
        [string] $from,
        [string] $to,
        [switch] $noBuild,
        [switch] $buildChainOnly,
        [switch] $noCache,
        [string[]] $CommandArgs
    )

    $argsToSave = @()
    if (-not [string]::IsNullOrWhiteSpace($Command)) { $argsToSave += $Command }
    if (-not [string]::IsNullOrWhiteSpace($env)) { $argsToSave += '-env'; $argsToSave += $env }
    if (-not [string]::IsNullOrWhiteSpace($client)) { $argsToSave += '-client'; $argsToSave += $client }
    if (-not [string]::IsNullOrWhiteSpace($scenario)) { $argsToSave += '-scenario'; $argsToSave += $scenario }
    $onlySelectors = @(Get-JaxOnlySelectors -Only $only)
    if ($onlySelectors.Count -gt 0) { $argsToSave += '-only'; $argsToSave += ($onlySelectors -join ',') }
    if (-not [string]::IsNullOrWhiteSpace($from)) { $argsToSave += '-from'; $argsToSave += $from }
    if (-not [string]::IsNullOrWhiteSpace($to)) { $argsToSave += '-to'; $argsToSave += $to }
    if ($noBuild) { $argsToSave += '-noBuild' }
    if ($buildChainOnly) { $argsToSave += '-buildChainOnly' }
    if ($noCache) { $argsToSave += '-noCache' }
    foreach ($carg in @($CommandArgs)) {
        if ($null -eq $carg) { continue }
        if ($carg -is [string] -and [string]::IsNullOrWhiteSpace($carg)) { continue }
        $argsToSave += $carg
    }
    # Always return [string[]]: a single-item array from `return $arr` is unwrapped to a scalar
    # in PowerShell, and '' then fails [string[]] parameter binding in callers.
    return [string[]]@($argsToSave)
}
