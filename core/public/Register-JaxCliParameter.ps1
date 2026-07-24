function Register-JaxCliParameter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [string[]] $Aliases = @(),
        [ValidateSet('switch', 'string')]
        [string] $Type = 'string',
        [string] $Scope = 'core'
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: Name=$Name"

    Initialize-JaxCliParameterRegistry

    $normalized = $Name.Trim().ToLowerInvariant()
    $aliasList = @()
    if ($Aliases) {
        $aliasList = @($Aliases | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Select-Object -Unique)
    }

    $script:JaxCliParameterRegistry = @($script:JaxCliParameterRegistry | Where-Object { $_.Name -ne $normalized })
    $script:JaxCliParameterRegistry += [pscustomobject]@{
        Name    = $normalized
        Aliases = $aliasList
        Type    = $Type
        Scope   = $Scope
    }
}
