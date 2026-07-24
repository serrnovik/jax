function Set-JaxContainerOverride {
    [CmdletBinding()]
    param (
        [object[]] $Entities,
        [string] $Image
    )

    if ($null -eq $Entities -or $Entities.Count -eq 0) {
        return @()
    }

    if ([string]::IsNullOrWhiteSpace($Image)) {
        return @($Entities)
    }

    $updated = @()
    foreach ($entity in $Entities) {
        if ($entity -isnot [System.Collections.IDictionary]) {
            $updated += $entity
            continue
        }

        $runner = $entity['Runner']
        if ([string]::IsNullOrWhiteSpace($runner)) {
            $runner = $entity['Type']
        }

        $normalized = Resolve-JaxRunnerName -Name $runner
        $entity['InnerRunner'] = $normalized
        $entity['Runner'] = 'container'

        if (-not $entity.Contains('Container') -or $null -eq $entity['Container']) {
            $entity['Container'] = @{ image = $Image }
        } elseif ($entity['Container'] -is [System.Collections.IDictionary]) {
            if (-not $entity['Container'].Contains('image')) {
                $entity['Container']['image'] = $Image
            }
        }

        $updated += $entity
    }

    return $updated
}
