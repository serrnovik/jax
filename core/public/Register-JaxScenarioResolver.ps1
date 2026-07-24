function Register-JaxScenarioResolver {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [scriptblock] $Handler,
        [int] $Order = 0
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: Name=$Name"

    Initialize-JaxScenarioResolverRegistry

    $normalized = $Name.ToLower()
    $existing = $script:JaxScenarioResolvers | Where-Object { $_.Name -eq $normalized }
    if ($existing) {
        $script:JaxScenarioResolvers = @($script:JaxScenarioResolvers | Where-Object { $_.Name -ne $normalized })
    }

    $script:JaxScenarioResolvers += [pscustomobject]@{
        Name    = $normalized
        Order   = $Order
        Handler = $Handler
    }
}
