function Get-JaxScenarioResolvers {
    [CmdletBinding()]
    param ()

    Initialize-JaxScenarioResolverRegistry

    if (-not $script:JaxScenarioResolvers) {
        return @()
    }

    return @($script:JaxScenarioResolvers | Sort-Object -Property Order, Name)
}
