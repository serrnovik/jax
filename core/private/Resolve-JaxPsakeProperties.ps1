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

    return $properties
}
