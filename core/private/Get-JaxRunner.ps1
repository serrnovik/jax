function Get-JaxRunner {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    Initialize-JaxRunnerRegistry

    $key = $Name.ToLower()
    if ($script:JaxRunnerRegistry.Keys -contains $key) {
        return $script:JaxRunnerRegistry[$key]
    }

    throw "No Jax runner registered for '$Name'."
}
