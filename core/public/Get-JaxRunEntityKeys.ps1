function Get-JaxRunEntityKeys {
    [CmdletBinding()]
    param (
        [object[]] $Entities,
        [switch] $IncludeAliases
    )

    if ($null -eq $Entities) {
        return @()
    }

    $keys = New-Object 'System.Collections.Generic.List[string]'
    $seen = @{}
    foreach ($entity in $Entities) {
        if ($null -eq $entity) {
            continue
        }
        $entityKey = Get-JaxRunEntityKey -Entity $entity
        if (-not [string]::IsNullOrWhiteSpace($entityKey)) {
            $normalized = Convert-JaxRunEntityName -Name $entityKey
            if (-not $seen.ContainsKey($normalized)) {
                $seen[$normalized] = $true
                $keys.Add($entityKey) | Out-Null
            }
        }
        if ($IncludeAliases) {
            foreach ($alias in Get-JaxRunEntityAliases -Entity $entity) {
                if ([string]::IsNullOrWhiteSpace($alias)) {
                    continue
                }
                $normalizedAlias = Convert-JaxRunEntityName -Name $alias
                if (-not $seen.ContainsKey($normalizedAlias)) {
                    $seen[$normalizedAlias] = $true
                    $keys.Add($alias) | Out-Null
                }
            }
        }
    }

    return @($keys | Sort-Object -Unique)
}
