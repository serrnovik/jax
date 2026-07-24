function Get-JaxRunEntityAliases {
    [CmdletBinding()]
    param (
        $Entity
    )

    if ($null -eq $Entity) {
        return @()
    }

    if ($Entity -is [System.Collections.IDictionary]) {
        if ($Entity.Contains('Aliases') -and $null -ne $Entity['Aliases']) {
            return @($Entity['Aliases'])
        }
        return @()
    }

    $props = $Entity.PSObject.Properties
    if ($props.Match('Aliases').Count -gt 0) {
        $aliases = $Entity.Aliases
        if ($null -ne $aliases) {
            return @($aliases)
        }
    }

    return @()
}
