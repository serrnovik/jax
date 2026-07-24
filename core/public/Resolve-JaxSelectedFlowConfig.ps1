function Resolve-JaxSelectedFlowConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Environment,
        [string] $PreferredConfig = 'build'
    )

    if ($null -eq $Environment.FlowConfigs -or $Environment.FlowConfigs.Count -eq 0) {
        return $null
    }

    $preferred = $PreferredConfig
    if (-not [string]::IsNullOrWhiteSpace($preferred)) {
        foreach ($config in $Environment.FlowConfigs) {
            if ($null -ne $config.Configuration -and $config.Configuration.ToLowerInvariant() -eq $preferred.ToLowerInvariant()) {
                return $config
            }
        }
    }

    return $Environment.FlowConfigs[0]
}
