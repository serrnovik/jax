function Test-JaxBobCiEnabled {
    [CmdletBinding()]
    param (
        [hashtable] $Context = @{},
        [System.Collections.IDictionary] $Layers
    )

    if ($null -ne $Layers -and $Layers.ContainsKey('ciEnabled')) {
        return [bool]$Layers['ciEnabled']
    }

    if ($Context.ContainsKey('Ci') -and [bool]$Context['Ci']) {
        return $true
    }
    if ($Context.ContainsKey('TeamCity') -and [bool]$Context['TeamCity']) {
        return $true
    }

    $envVars = @()
    if ($null -ne $Layers -and $Layers.ContainsKey('ciEnvVars')) {
        $envVars = @($Layers['ciEnvVars'])
    }
    if ($envVars.Count -eq 0) {
        $envVars = @(
            'CI',
            'GITHUB_ACTIONS',
            'GITLAB_CI',
            'JENKINS_URL',
            'TF_BUILD',
            'TRAVIS',
            'CIRCLECI',
            'APPVEYOR',
            'BITBUCKET_COMMIT',
            'BUILDKITE',
            'TEAMCITY_VERSION'
        )
    }

    foreach ($name in $envVars) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }
        $value = [Environment]::GetEnvironmentVariable($name)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $true
        }
    }

    return $false
}
