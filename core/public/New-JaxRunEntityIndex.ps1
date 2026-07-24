function New-JaxRunEntityIndex {
    [CmdletBinding()]
    param (
        [object[]] $Entities
    )

    $index = @{}
    foreach ($entity in @($Entities)) {
        if ($null -eq $entity) {
            continue
        }
        $key = Get-JaxRunEntityKey -Entity $entity
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $normalizedKey = Convert-JaxRunEntityName -Name $key
            if (-not [string]::IsNullOrWhiteSpace($normalizedKey)) {
                $index[$normalizedKey] = $entity
            }
        }
        foreach ($alias in Get-JaxRunEntityAliases -Entity $entity) {
            if (-not [string]::IsNullOrWhiteSpace($alias)) {
                $normalizedAlias = Convert-JaxRunEntityName -Name $alias
                if (-not [string]::IsNullOrWhiteSpace($normalizedAlias)) {
                    $index[$normalizedAlias] = $entity
                }
            }
        }
    }

    return $index
}
