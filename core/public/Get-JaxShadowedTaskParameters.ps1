function Get-JaxShadowedTaskParameters {
    <#
    .SYNOPSIS
    Task/script parameters whose names Jax's own CLI flags already take.

    .DESCRIPTION
    Jax binds its own flags (-env, -client, -only, -noCache, ...) before it binds a
    task's parameters, and a task parameter sharing one of those names is dropped
    from the property bag instead of shadowing the flag. Left unreported the drop is
    silent, which is how `-client codex` came to select a Jax environment namespace
    while the psake task kept its default and registered the wrong client.

    Returns one entry per colliding name:

        Name       - the parameter name Jax owns
        Entities   - keys of the planned entities that declare it
        Supplied   - $true when that flag was typed on this command line

    Callers decide what to do with each: a collision the user did not type is worth
    a warning, one they did type is an error, because the value they asked for
    cannot reach the task at all.
    #>
    [CmdletBinding()]
    param (
        [object[]] $Entities,
        [Parameter(Mandatory = $true)]
        [string[]] $ReservedNames,
        [System.Collections.IDictionary] $SuppliedOptions,
        [hashtable] $Context = @{},
        [hashtable] $CommonParameters = @{}
    )

    if ($null -eq $Entities -or $Entities.Count -eq 0) {
        return @()
    }

    $reserved = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @($ReservedNames)) {
        if ([string]::IsNullOrWhiteSpace([string]$name)) { continue }
        $reserved.Add([string]$name) | Out-Null
    }
    # 'Command'/'CommandArgs' are Jax's positional parameters, not flags a user
    # would ever mean as a task parameter; reporting them would be noise.
    foreach ($name in @('Command', 'CommandArgs')) {
        $reserved.Remove($name) | Out-Null
    }

    $collisions = [ordered]@{}
    foreach ($entity in @($Entities)) {
        if ($entity -isnot [System.Collections.IDictionary]) { continue }
        $entityKey = [string]$entity['Key']
        foreach ($declared in @(Get-JaxEntityDeclaredParameterNames -Entity $entity -Context $Context -CommonParameters $CommonParameters)) {
            if (-not $reserved.Contains($declared)) { continue }
            if (-not $collisions.Contains($declared)) {
                $collisions[$declared] = @()
            }
            if (-not [string]::IsNullOrWhiteSpace($entityKey) -and $collisions[$declared] -notcontains $entityKey) {
                $collisions[$declared] += $entityKey
            }
        }
    }

    $results = @()
    foreach ($name in @($collisions.Keys)) {
        $supplied = $false
        if ($null -ne $SuppliedOptions -and $SuppliedOptions.Contains($name)) {
            $value = $SuppliedOptions[$name]
            # A switch left at $false was not really asked for.
            $supplied = -not ($value -is [bool] -and -not $value)
        }
        $results += [ordered]@{
            Name     = $name
            Entities = @($collisions[$name])
            Supplied = $supplied
        }
    }

    return $results
}
