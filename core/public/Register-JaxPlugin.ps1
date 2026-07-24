function Register-JaxPlugin {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [hashtable] $Hooks = @{},
        [string] $SourcePath
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: Name=$Name"

    Initialize-JaxPluginRegistry

    $normalized = $Name.ToLower()
    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        if ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.PSObject.Properties['Path']) {
            $SourcePath = $MyInvocation.MyCommand.Path
        } elseif ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.PSObject.Properties['Name']) {
            $SourcePath = $MyInvocation.MyCommand.Name
        }
    }

    $script:JaxPluginRegistry = @(
        $script:JaxPluginRegistry | Where-Object { $_.Name -ne $normalized }
    )

    $script:JaxPluginRegistry += [pscustomobject]@{
        Name       = $normalized
        Hooks      = $Hooks
        SourcePath = $SourcePath
    }
}
