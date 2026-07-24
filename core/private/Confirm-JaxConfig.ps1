function Confirm-JaxConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Config,
        [string] $SourcePath
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $errors = New-Object 'System.Collections.Generic.List[string]'

    function Add-JaxConfigError {
        param (
            [string] $KeyPath,
            [string] $Message
        )

        $line = $null
        if (-not [string]::IsNullOrWhiteSpace($SourcePath)) {
            $line = Find-JaxConfigLine -Path $SourcePath -KeyPath $KeyPath
        }

        $lineSuffix = if ($null -ne $line) { " (line $line)" } else { "" }
        $errors.Add("${KeyPath}: $Message$lineSuffix") | Out-Null
    }

    function Get-JaxValueTypeName {
        param (
            [object] $Value
        )

        if ($null -eq $Value) {
            return 'null'
        }
        return $Value.GetType().Name
    }

    function Test-JaxIsList {
        param (
            [object] $Value
        )

        if ($null -eq $Value) {
            return $false
        }
        if ($Value -is [string]) {
            return $false
        }
        if ($Value -is [System.Collections.IDictionary]) {
            return $false
        }
        return ($Value -is [System.Collections.IEnumerable])
    }

    function Test-JaxStringList {
        param (
            [object] $Value
        )

        if ($Value -is [string]) {
            return $true
        }
        if (-not (Test-JaxIsList -Value $Value)) {
            return $false
        }
        foreach ($item in $Value) {
            if (-not ($item -is [string])) {
                return $false
            }
        }
        return $true
    }

    if ($Config.Keys -contains 'envRoot' -and -not ($Config['envRoot'] -is [string])) {
        Add-JaxConfigError -KeyPath 'envRoot' -Message "expected string, got $(Get-JaxValueTypeName $Config['envRoot'])"
    }
    if ($Config.Keys -contains 'dummyEnv') {
        if ($Config['dummyEnv'] -is [string]) {
            # ok: shorthand name
        } elseif (-not (Test-JaxIsDictionary -Value $Config['dummyEnv'])) {
            Add-JaxConfigError -KeyPath 'dummyEnv' -Message "expected string or map/object, got $(Get-JaxValueTypeName $Config['dummyEnv'])"
        } else {
            $dummyEnv = $Config['dummyEnv']
            if ($dummyEnv.Keys -contains 'enabled' -and -not ($dummyEnv['enabled'] -is [bool])) {
                Add-JaxConfigError -KeyPath 'dummyEnv.enabled' -Message "expected boolean, got $(Get-JaxValueTypeName $dummyEnv['enabled'])"
            }
            if ($dummyEnv.Keys -contains 'name' -and -not ($dummyEnv['name'] -is [string])) {
                Add-JaxConfigError -KeyPath 'dummyEnv.name' -Message "expected string, got $(Get-JaxValueTypeName $dummyEnv['name'])"
            }
            if ($dummyEnv.Keys -contains 'skipEnvRoot' -and -not ($dummyEnv['skipEnvRoot'] -is [bool])) {
                Add-JaxConfigError -KeyPath 'dummyEnv.skipEnvRoot' -Message "expected boolean, got $(Get-JaxValueTypeName $dummyEnv['skipEnvRoot'])"
            }
        }
    }
    if ($Config.Keys -contains 'flowDirNames' -and -not (Test-JaxStringList -Value $Config['flowDirNames'])) {
        Add-JaxConfigError -KeyPath 'flowDirNames' -Message 'expected string or list of strings'
    }
    if ($Config.Keys -contains 'flowFilePatterns' -and -not (Test-JaxStringList -Value $Config['flowFilePatterns'])) {
        Add-JaxConfigError -KeyPath 'flowFilePatterns' -Message 'expected string or list of strings'
    }
    if ($Config.Keys -contains 'buildSectionNames' -and -not (Test-JaxStringList -Value $Config['buildSectionNames'])) {
        Add-JaxConfigError -KeyPath 'buildSectionNames' -Message 'expected string or list of strings'
    }
    if ($Config.Keys -contains 'buildSectionName' -and -not (Test-JaxStringList -Value $Config['buildSectionName'])) {
        Add-JaxConfigError -KeyPath 'buildSectionName' -Message 'expected string or list of strings'
    }
    if ($Config.Keys -contains 'conventionalEnvRoots' -and -not (Test-JaxStringList -Value $Config['conventionalEnvRoots'])) {
        Add-JaxConfigError -KeyPath 'conventionalEnvRoots' -Message 'expected string or list of strings'
    }
    if ($Config.Keys -contains 'buildEnvRoots' -and -not (Test-JaxStringList -Value $Config['buildEnvRoots'])) {
        Add-JaxConfigError -KeyPath 'buildEnvRoots' -Message 'expected string or list of strings'
    }
    if ($Config.Keys -contains 'buildEnvRoot' -and -not (Test-JaxStringList -Value $Config['buildEnvRoot'])) {
        Add-JaxConfigError -KeyPath 'buildEnvRoot' -Message 'expected string or list of strings'
    }
    if ($Config.Keys -contains 'commonDirName' -and -not ($Config['commonDirName'] -is [string])) {
        Add-JaxConfigError -KeyPath 'commonDirName' -Message "expected string, got $(Get-JaxValueTypeName $Config['commonDirName'])"
    }
    if ($Config.Keys -contains 'scenarioLibDirName' -and -not ($Config['scenarioLibDirName'] -is [string])) {
        Add-JaxConfigError -KeyPath 'scenarioLibDirName' -Message "expected string, got $(Get-JaxValueTypeName $Config['scenarioLibDirName'])"
    }
    if ($Config.Keys -contains 'modulePathInGit' -and -not (Test-JaxIsDictionary -Value $Config['modulePathInGit'])) {
        Add-JaxConfigError -KeyPath 'modulePathInGit' -Message "expected map/object, got $(Get-JaxValueTypeName $Config['modulePathInGit'])"
    }
    if ($Config.Keys -contains 'taskIgnoreList' -and -not (Test-JaxStringList -Value $Config['taskIgnoreList'])) {
        Add-JaxConfigError -KeyPath 'taskIgnoreList' -Message 'expected string or list of strings'
    }
    if ($Config.Keys -contains 'aliases' -and -not (Test-JaxIsDictionary -Value $Config['aliases'])) {
        Add-JaxConfigError -KeyPath 'aliases' -Message "expected map/object, got $(Get-JaxValueTypeName $Config['aliases'])"
    }
    if ($Config.Keys -contains 'shortcuts' -and -not (Test-JaxIsDictionary -Value $Config['shortcuts'])) {
        Add-JaxConfigError -KeyPath 'shortcuts' -Message "expected map/object, got $(Get-JaxValueTypeName $Config['shortcuts'])"
    }

    if ($Config.Keys -contains 'plugins') {
        if (-not (Test-JaxIsDictionary -Value $Config['plugins'])) {
            Add-JaxConfigError -KeyPath 'plugins' -Message "expected map/object, got $(Get-JaxValueTypeName $Config['plugins'])"
        } else {
            $plugins = $Config['plugins']
            if ($plugins.Keys -contains 'enabled' -and -not (Test-JaxStringList -Value $plugins['enabled'])) {
                Add-JaxConfigError -KeyPath 'plugins.enabled' -Message 'expected string or list of strings'
            }
            if ($plugins.Keys -contains 'disabled' -and -not (Test-JaxStringList -Value $plugins['disabled'])) {
                Add-JaxConfigError -KeyPath 'plugins.disabled' -Message 'expected string or list of strings'
            }
            if ($plugins.Keys -contains 'paths' -and -not (Test-JaxStringList -Value $plugins['paths'])) {
                Add-JaxConfigError -KeyPath 'plugins.paths' -Message 'expected string or list of strings'
            }
            if ($plugins.Keys -contains 'config' -and -not (Test-JaxIsDictionary -Value $plugins['config'])) {
                Add-JaxConfigError -KeyPath 'plugins.config' -Message "expected map/object, got $(Get-JaxValueTypeName $plugins['config'])"
            }
            if ($plugins.Keys -contains 'config' -and (Test-JaxIsDictionary -Value $plugins['config'])) {
                $pluginConfig = $plugins['config']
                if ($pluginConfig.Keys -contains 'vault' -and (Test-JaxIsDictionary -Value $pluginConfig['vault'])) {
                    $vaultCfg = $pluginConfig['vault']
                    if ($vaultCfg.Keys -contains 'policy' -and -not ($vaultCfg['policy'] -is [string])) {
                        Add-JaxConfigError -KeyPath 'plugins.config.vault.policy' -Message "expected string, got $(Get-JaxValueTypeName $vaultCfg['policy'])"
                    }
                    if ($vaultCfg.Keys -contains 'tokenTtl' -and -not ($vaultCfg['tokenTtl'] -is [string])) {
                        Add-JaxConfigError -KeyPath 'plugins.config.vault.tokenTtl' -Message "expected string, got $(Get-JaxValueTypeName $vaultCfg['tokenTtl'])"
                    }
                }
            }
        }
    }

    if ($Config.Keys -contains 'tasks') {
        if (-not (Test-JaxIsDictionary -Value $Config['tasks'])) {
            Add-JaxConfigError -KeyPath 'tasks' -Message "expected map/object, got $(Get-JaxValueTypeName $Config['tasks'])"
        } else {
            $tasks = $Config['tasks']
            if ($tasks.Keys -contains 'psakeFilePattern' -and -not ($tasks['psakeFilePattern'] -is [string])) {
                Add-JaxConfigError -KeyPath 'tasks.psakeFilePattern' -Message "expected string, got $(Get-JaxValueTypeName $tasks['psakeFilePattern'])"
            }
            if ($tasks.Keys -contains 'nonConventionalDirs' -and -not (Test-JaxStringList -Value $tasks['nonConventionalDirs'])) {
                Add-JaxConfigError -KeyPath 'tasks.nonConventionalDirs' -Message 'expected string or list of strings'
            }
        }
    }

    if ($Config.Keys -contains 'scripts') {
        if (-not (Test-JaxIsDictionary -Value $Config['scripts'])) {
            Add-JaxConfigError -KeyPath 'scripts' -Message "expected map/object, got $(Get-JaxValueTypeName $Config['scripts'])"
        } else {
            $scripts = $Config['scripts']
            if ($scripts.Keys -contains 'dirNames' -and -not (Test-JaxStringList -Value $scripts['dirNames'])) {
                Add-JaxConfigError -KeyPath 'scripts.dirNames' -Message 'expected string or list of strings'
            }
            if ($scripts.Keys -contains 'nonConventionalDirs' -and -not (Test-JaxStringList -Value $scripts['nonConventionalDirs'])) {
                Add-JaxConfigError -KeyPath 'scripts.nonConventionalDirs' -Message 'expected string or list of strings'
            }
        }
    }

    if ($Config.Keys -contains 'cache') {
        if (-not (Test-JaxIsDictionary -Value $Config['cache'])) {
            Add-JaxConfigError -KeyPath 'cache' -Message "expected map/object, got $(Get-JaxValueTypeName $Config['cache'])"
        } else {
            $cache = $Config['cache']
            if ($cache.Keys -contains 'enabled' -and -not ($cache['enabled'] -is [bool])) {
                Add-JaxConfigError -KeyPath 'cache.enabled' -Message "expected boolean, got $(Get-JaxValueTypeName $cache['enabled'])"
            }
            if ($cache.Keys -contains 'dir' -and -not ($cache['dir'] -is [string])) {
                Add-JaxConfigError -KeyPath 'cache.dir' -Message "expected string, got $(Get-JaxValueTypeName $cache['dir'])"
            }
        }
    }

    if ($errors.Count -gt 0) {
        $sourceLabel = if ([string]::IsNullOrWhiteSpace($SourcePath)) { 'Jax config' } else { $SourcePath }
        $message = "Invalid Jax config in '$sourceLabel':`n" + ($errors -join "`n")
        throw $message
    }
}
