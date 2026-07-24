function Convert-JaxRunEntityName {
    [CmdletBinding()]
    param (
        [string] $Name
    )

    # Convert-JaxRunEntityName is called very frequently.
    # We avoid Get-JaxCommonParameters here if performance is a concern, but consistency is better for now.
    # $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    # Actually, let's keep it consistent.
    # Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $Name"
    # Reducing verbosity for this utility function to avoid log spam, or keep it?
    # User asked for "each function".
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $Name"

    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return ''
    }

    $normalized = $Name -replace '[\\/\s]', ''
    return $normalized.Trim().ToLowerInvariant()
}
