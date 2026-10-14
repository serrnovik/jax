function Resolve-JaxPsakeProperties {
    <#
    .SYNOPSIS
    Builds the psake -properties bag for a run entity.

    .DESCRIPTION
    Single source of truth for the property merge order, so the dry-run preview
    and the real invocation can never drift apart:

        RunConfig  ->  PsakeProperties  ->  Entity.Args  ->  CliArgs   (last wins)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Entity,
        [hashtable] $Context = @{},
        [hashtable] $CommonParameters = @{}
    )

    $properties = @{}
    $baseProps = $null
    if ($Context.ContainsKey('PsakeProperties') -and $Context['PsakeProperties'] -is [System.Collections.IDictionary]) {
        $baseProps = $Context['PsakeProperties']
    }
    if ($Context.ContainsKey('RunConfig') -and $Context['RunConfig'] -is [System.Collections.IDictionary]) {
        if ($null -eq $baseProps) {
            $baseProps = $Context['RunConfig']
        } else {
            # precedence: psake properties override run-config defaults
            $baseProps = Merge-JaxHashtable -Base $Context['RunConfig'] -Overlay $baseProps @CommonParameters
        }
    }
    if ($null -ne $baseProps) {
        $properties = Merge-JaxHashtable -Base @{} -Overlay $baseProps @CommonParameters
    }
    if ($Entity['Args'] -is [System.Collections.IDictionary]) {
        $properties = Merge-JaxHashtable -Base $properties -Overlay $Entity['Args'] @CommonParameters
    }
    # CLI DynamicParam-bound task params: apply last (highest precedence)
    if ($Context.ContainsKey('CliArgs') -and $Context['CliArgs'] -is [System.Collections.IDictionary]) {
        $properties = Merge-JaxHashtable -Base $properties -Overlay $Context['CliArgs'] @CommonParameters
    }

    # A [bool] property overridden as text (`-flag:$false` that DynamicParam could not
    # bind, a flow `args:` value, a run-config string) reaches psake as the string
    # 'False': it then fails to bind to any [bool] parameter, and is truthy in `if`.
    # Hand the declared type back.
    foreach ($name in @(Get-JaxDeclaredBoolParameterNames -Entity $Entity)) {
        if (-not $properties.ContainsKey($name)) { continue }
        $value = $properties[$name]
        if ($null -eq $value -or $value -is [bool]) { continue }
        $properties[$name] = Convert-JaxCliSwitchValue -Value $value
    }

    return $properties
}

function Get-JaxDeclaredBoolParameterNames {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Entity
    )

    if (-not $Entity.Contains('Definition') -or $Entity['Definition'] -isnot [System.Collections.IDictionary]) {
        return @()
    }
    $definition = $Entity['Definition']
    if (-not $definition.Contains('Parameters')) {
        return @()
    }
    $boolTypes = @('bool', 'boolean', 'system.boolean', 'switch', 'switchparameter', 'system.management.automation.switchparameter')
    $names = @()
    foreach ($p in @($definition['Parameters'])) {
        if ($p -isnot [System.Collections.IDictionary]) { continue }
        $type = ([string]$p['Type']).Trim().TrimStart('[').TrimEnd(']').ToLowerInvariant()
        if ($boolTypes -contains $type -and -not [string]::IsNullOrWhiteSpace([string]$p['Name'])) {
            $names += [string]$p['Name']
        }
    }
    return $names
}
