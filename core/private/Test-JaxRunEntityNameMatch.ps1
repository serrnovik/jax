function Test-JaxRunEntityNameMatch {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Entity,
        [string] $Name,
        [switch] $MatchStartsWith
    )

    if ($null -eq $Entity) {
        return $false
    }

    if ($MatchStartsWith -and [string]::IsNullOrWhiteSpace($Name)) {
        return $true
    }

    if (-not $MatchStartsWith -and [string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    $needle = Convert-JaxRunEntityName -Name $Name
    if ([string]::IsNullOrWhiteSpace($needle)) {
        return $false
    }

    $candidates = @()
    $key = Get-JaxRunEntityKey -Entity $Entity
    if (-not [string]::IsNullOrWhiteSpace($key)) {
        $candidates += $key
    }
    $aliases = @(Get-JaxRunEntityAliases -Entity $Entity)
    if ($aliases.Count -gt 0) {
        $candidates += $aliases
    }

    # Also match against Task property (psake/bob)
    if ($Entity -is [System.Collections.IDictionary] -and $Entity.Contains('Task')) {
        if (-not [string]::IsNullOrWhiteSpace($Entity['Task'])) { $candidates += $Entity['Task'] }
    } elseif ($null -ne $Entity.PSObject.Properties['Task']) {
        if (-not [string]::IsNullOrWhiteSpace($Entity.Task)) { $candidates += $Entity.Task }
    }

    # Also match against Tasks property (plural)
    if ($Entity -is [System.Collections.IDictionary] -and $Entity.Contains('Tasks')) {
        $tasks = $Entity['Tasks']
        if ($tasks -is [string]) { $candidates += $tasks }
        elseif ($tasks -is [System.Collections.IEnumerable]) { $candidates += $tasks }
    } elseif ($null -ne $Entity.PSObject.Properties['Tasks']) {
        $tasks = $Entity.Tasks
        if ($tasks -is [string]) { $candidates += $tasks }
        elseif ($tasks -is [System.Collections.IEnumerable]) { $candidates += $tasks }
    }

    # Also match against Script basename (script runner)
    if ($Entity -is [System.Collections.IDictionary] -and $Entity.Contains('Script')) {
        if (-not [string]::IsNullOrWhiteSpace($Entity['Script'])) {
            $candidates += [System.IO.Path]::GetFileNameWithoutExtension([string]$Entity['Script'])
        }
    } elseif ($null -ne $Entity.PSObject.Properties['Script']) {
        if (-not [string]::IsNullOrWhiteSpace($Entity.Script)) {
            $candidates += [System.IO.Path]::GetFileNameWithoutExtension([string]$Entity.Script)
        }
    }

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        $normalized = Convert-JaxRunEntityName -Name $candidate
        if ($MatchStartsWith) {
            if ($normalized.StartsWith($needle)) {
                return $true
            }
        } elseif ($normalized -eq $needle) {
            return $true
        }
    }

    return $false
}
