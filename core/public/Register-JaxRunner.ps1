function Register-JaxRunner {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [scriptblock] $Handler
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: Name=$Name"

    if ($null -eq $script:JaxRunnerRegistry) {
        $script:JaxRunnerRegistry = @{}
    }

    $key = $Name.ToLower()
    $script:JaxRunnerRegistry[$key] = $Handler
}
