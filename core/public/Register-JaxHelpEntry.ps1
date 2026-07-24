function Register-JaxHelpEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [string] $Summary,
        [string[]] $Usage = @(),
        [string] $Source = 'core'
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: Name=$Name"

    Initialize-JaxHelpRegistry

    $normalized = $Name.Trim().ToLowerInvariant()
    $entries = @($script:JaxHelpRegistry | Where-Object { $_.Name -ne $normalized })
    $entries += [pscustomobject]@{
        Name    = $normalized
        Summary = $Summary
        Usage   = $Usage
        Source  = $Source
    }
    $script:JaxHelpRegistry = $entries
}
