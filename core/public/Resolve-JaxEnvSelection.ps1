function Resolve-JaxEnvSelection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object[]] $Environments,
        [string] $Env,
        [string] $Client
    )

    $selected = $null
    $flowOverride = $null
    $errorMessage = $null

    try {
        $selected = Resolve-JaxSelectedEnvironment -Environments $Environments -Env $Env -Client $Client
    } catch {
        $errorMessage = $_.Exception.Message
    }

    if ($null -eq $selected -and -not [string]::IsNullOrWhiteSpace($Env) -and $Env.Contains('/')) {
        $parts = $Env -split '/'
        if ($parts.Count -gt 1) {
            $flowOverride = $parts[-1]
            $envCandidate = ($parts[0..($parts.Count - 2)] -join '/')
            try {
                $selected = Resolve-JaxSelectedEnvironment -Environments $Environments -Env $envCandidate -Client $Client
            } catch {
                if ([string]::IsNullOrWhiteSpace($errorMessage)) {
                    $errorMessage = $_.Exception.Message
                }
            }
        }
    }

    if ($null -eq $selected) {
        if ([string]::IsNullOrWhiteSpace($errorMessage)) {
            $errorMessage = "Environment '$Env' was not found."
        }
        throw $errorMessage
    }

    return [pscustomobject]@{
        Environment  = $selected
        FlowOverride = $flowOverride
    }
}
