function Select-JaxRunEntities {
    [CmdletBinding()]
    param (
        [object[]] $Entities,
        [string] $Only,
        [string] $From,
        [string] $To
    )

    if ($null -eq $Entities) {
        return @()
    }

    $items = @()
    if ($Entities -is [System.Collections.IEnumerable] -and $Entities -isnot [string] -and $Entities -isnot [System.Collections.IDictionary]) {
        $items = @($Entities)
    } else {
        $items = , $Entities
    }
    if ($items.Count -eq 0) {
        return @()
    }

    if (-not [string]::IsNullOrWhiteSpace($Only)) {
        # Runtime selection must be deterministic: -Only matches EXACT keys/aliases (autocomplete handles partial).
        $onlyNeedle = Convert-JaxRunEntityName -Name $Only

        # Prefer exact match against the entity Key when present (avoids accidentally matching scenario steps by Tasks).
        $keyMatches = @()
        foreach ($item in $items) {
            $k = Get-JaxRunEntityKey -Entity $item
            if ([string]::IsNullOrWhiteSpace($k)) {
                continue
            }
            if ((Convert-JaxRunEntityName -Name $k) -eq $onlyNeedle) {
                $keyMatches += , $item
            }
        }
        if ($keyMatches.Count -gt 0) {
            return $keyMatches
        }

        # Fallback to full name matching (aliases/task/tasks/script basename)
        $filtered = @()
        foreach ($item in $items) {
            if (Test-JaxRunEntityNameMatch -Entity $item -Name $Only) {
                $filtered += , $item
            }
        }
        return $filtered
    }

    $fromIndex = $null
    if (-not [string]::IsNullOrWhiteSpace($From)) {
        for ($i = 0; $i -lt $items.Count; $i++) {
            if (Test-JaxRunEntityNameMatch -Entity $items[$i] -Name $From) {
                $fromIndex = $i
                break
            }
        }
        if ($null -eq $fromIndex) {
            return @()
        }
    } else {
        $fromIndex = 0
    }

    $toIndex = $null
    if (-not [string]::IsNullOrWhiteSpace($To)) {
        for ($i = $fromIndex; $i -lt $items.Count; $i++) {
            if (Test-JaxRunEntityNameMatch -Entity $items[$i] -Name $To) {
                $toIndex = $i
                break
            }
        }
        if ($null -eq $toIndex) {
            return @()
        }
    } else {
        $toIndex = $items.Count - 1
    }

    if ($fromIndex -gt $toIndex) {
        return @()
    }

    return @($items[$fromIndex..$toIndex])
}
