function Get-JaxRunEntityKey {
    [CmdletBinding()]
    param (
        $Entity
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if ($null -eq $Entity) {
        return $null
    }

    if ($Entity -is [string]) {
        return $Entity
    }

    if ($Entity -is [System.Collections.IDictionary]) {
        if ($Entity.Contains('Key')) {
            return $Entity['Key']
        }
        if ($Entity.Contains('Name')) {
            return $Entity['Name']
        }
    }

    $properties = $Entity.PSObject.Properties
    if ($properties.Match('Key').Count -gt 0) {
        return $Entity.Key
    }
    if ($properties.Match('Name').Count -gt 0) {
        return $Entity.Name
    }

    return $Entity.ToString()
}
