function Convert-JaxConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Config
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $flowDirNames = $null
    if ($Config.Keys -contains 'flowDirName') {
        $flowDirNames = @($Config['flowDirName'])
    } elseif ($Config.Keys -contains 'bossDirName') {
        $flowDirNames = @('flows', $Config['bossDirName'])
    } elseif ($Config.Keys -contains 'bossDirNames') {
        $flowDirNames = @('flows') + @($Config['bossDirNames'])
    } elseif ($Config.Keys -contains 'flowDirNames') {
        $flowDirNames = $Config['flowDirNames']
    }

    if ($null -eq $flowDirNames -or @($flowDirNames).Count -eq 0) {
        $flowDirNames = @('flows')
    }

    if ($flowDirNames -is [string]) {
        $flowDirNames = @($flowDirNames)
    }

    $flowDirNames = @($flowDirNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($flowDirNames.Count -eq 0) {
        $flowDirNames = @('flows')
    }

    $Config['flowDirNames'] = $flowDirNames
    foreach ($legacyKey in @('flowDirName', 'bossDirName', 'bossDirNames')) {
        if ($Config.Keys -contains $legacyKey) {
            $Config.Remove($legacyKey) | Out-Null
        }
    }

    $flowFilePatterns = $null
    if ($Config.Keys -contains 'flowFilePatterns') {
        $flowFilePatterns = $Config['flowFilePatterns']
    } elseif ($Config.Keys -contains 'bossFilePatterns') {
        $flowFilePatterns = $Config['bossFilePatterns']
    }

    if ($null -eq $flowFilePatterns -or $flowFilePatterns.Count -eq 0) {
        $flowFilePatterns = @('*.yml', '*.yaml')
    }

    if ($flowFilePatterns -is [string]) {
        $flowFilePatterns = @($flowFilePatterns)
    }

    $flowFilePatterns = @($flowFilePatterns | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($flowFilePatterns.Count -eq 0) {
        $flowFilePatterns = @('*.yml', '*.yaml')
    }

    $Config['flowFilePatterns'] = $flowFilePatterns
    if ($Config.Keys -contains 'bossFilePatterns') {
        $Config.Remove('bossFilePatterns') | Out-Null
    }

    $buildSectionNames = $null
    if ($Config.Keys -contains 'buildSectionName') {
        $buildSectionNames = @($Config['buildSectionName'])
    } elseif ($Config.Keys -contains 'buildSectionNames') {
        $buildSectionNames = $Config['buildSectionNames']
    }
    if ($buildSectionNames -is [string]) {
        $buildSectionNames = @($buildSectionNames)
    }
    if ($null -ne $buildSectionNames) {
        $buildSectionNames = @($buildSectionNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    if ($null -eq $buildSectionNames -or $buildSectionNames.Count -eq 0) {
        $buildSectionNames = @('build', 'modules')
    }
    $Config['buildSectionNames'] = $buildSectionNames
    if ($Config.Keys -contains 'buildSectionName') {
        $Config.Remove('buildSectionName') | Out-Null
    }

    # Canonical key is `conventionalEnvRoots`. Legacy aliases (`buildEnvRoot` singular,
    # `buildEnvRoots` plural) are checked FIRST so they win over the canonical key when
    # both are present in the merged config — the canonical key may be inherited from
    # Get-JaxDefaultConfig, while a legacy key in the user/repo config represents an
    # explicit override (same pattern as `flowDirName` → `flowDirNames` above).
    $conventionalEnvRoots = $null
    if ($Config.Keys -contains 'buildEnvRoot') {
        $conventionalEnvRoots = @($Config['buildEnvRoot'])
    } elseif ($Config.Keys -contains 'buildEnvRoots') {
        $conventionalEnvRoots = $Config['buildEnvRoots']
    } elseif ($Config.Keys -contains 'conventionalEnvRoots') {
        $conventionalEnvRoots = $Config['conventionalEnvRoots']
    }
    if ($conventionalEnvRoots -is [string]) {
        $conventionalEnvRoots = @($conventionalEnvRoots)
    }
    if ($null -eq $conventionalEnvRoots) {
        $conventionalEnvRoots = @('code')
    } else {
        $conventionalEnvRoots = @($conventionalEnvRoots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    $Config['conventionalEnvRoots'] = $conventionalEnvRoots
    if ($Config.Keys -contains 'buildEnvRoots') {
        $Config.Remove('buildEnvRoots') | Out-Null
    }
    if ($Config.Keys -contains 'buildEnvRoot') {
        $Config.Remove('buildEnvRoot') | Out-Null
    }

    $dummyEnv = $null
    if ($Config.Keys -contains 'dummyEnv') {
        $dummyEnv = $Config['dummyEnv']
    }

    if ($dummyEnv -is [string]) {
        $dummyEnv = @{ name = $dummyEnv }
    }
    if ($dummyEnv -isnot [System.Collections.IDictionary]) {
        $dummyEnv = @{}
    }

    $dummyEnabled = $true
    if ($dummyEnv.Keys -contains 'enabled') {
        $dummyEnabled = [bool]$dummyEnv['enabled']
    }
    $dummyName = 'none'
    if ($dummyEnv.Keys -contains 'name' -and -not [string]::IsNullOrWhiteSpace([string]$dummyEnv['name'])) {
        $dummyName = [string]$dummyEnv['name']
    }
    $skipEnvRoot = $true
    if ($dummyEnv.Keys -contains 'skipEnvRoot') {
        $skipEnvRoot = [bool]$dummyEnv['skipEnvRoot']
    }

    $Config['dummyEnv'] = @{
        enabled     = $dummyEnabled
        name        = $dummyName
        skipEnvRoot = $skipEnvRoot
    }

    if ($Config.Keys -contains 'plugins' -and $Config['plugins'] -is [System.Collections.IDictionary]) {
        $plugins = $Config['plugins']
        foreach ($listKey in @('enabled', 'disabled', 'paths')) {
            if ($plugins.Keys -contains $listKey) {
                $value = $plugins[$listKey]
                if ($value -is [string]) {
                    $plugins[$listKey] = @($value)
                }
                if ($plugins[$listKey] -is [System.Collections.IEnumerable] -and $plugins[$listKey] -isnot [string] -and $listKey -ne 'paths') {
                    $plugins[$listKey] = @($plugins[$listKey] | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.ToLower() })
                }
            }
        }
        if ($plugins.Keys -notcontains 'enabled' -or $null -eq $plugins['enabled']) {
            $plugins['enabled'] = @()
        }
        if ($plugins.Keys -notcontains 'disabled' -or $null -eq $plugins['disabled']) {
            $plugins['disabled'] = @()
        }
        if (($plugins['enabled'] -notcontains 'bob') -and ($plugins['disabled'] -notcontains 'bob')) {
            $plugins['enabled'] += 'bob'
        }
        if ($plugins.Keys -notcontains 'config' -or $null -eq $plugins['config']) {
            $plugins['config'] = @{}
        }
        $Config['plugins'] = $plugins
    }

    return $Config
}
