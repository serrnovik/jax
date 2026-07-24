function Initialize-JaxScenarioResolverRegistry {
    [CmdletBinding()]
    param ()

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    # Initialize if not set, or clear if duplicates exist (stale reload state)
    $existingNames = @()
    if (Test-Path variable:script:JaxScenarioResolvers) {
        $existingNames = @($script:JaxScenarioResolvers | ForEach-Object { $_.Name })
        $duplicates = $existingNames | Group-Object | Where-Object { $_.Count -gt 1 }
        if ($duplicates) {
            # Found duplicates, clear and rebuild
            $script:JaxScenarioResolvers = @()
            $existingNames = @()
        }
    } else {
        # Not initialized yet
        $script:JaxScenarioResolvers = @()
    }

    if ($existingNames -notcontains 'dictionary') {
        $script:JaxScenarioResolvers += [pscustomobject]@{
            Name    = 'dictionary'
            Order   = 0
            Handler = {
                [CmdletBinding()]
                param($Key, $Value, $ScenarioName, $ProvenancePath, $Context)

                $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
                Write-Debug "RESOLVER: dictionary Key: $Key"

                if ($Value -isnot [System.Collections.IDictionary]) {
                    return $null
                }

                $entity = New-JaxRunEntity -Key $Key -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath @commonParams

                if (Test-JaxDictionaryHasKey -Dictionary $Value -Key 'runner' @commonParams) {
                    $entity['Runner'] = Resolve-JaxRunnerName -Name $Value['runner'] @commonParams
                } elseif (Test-JaxDictionaryHasKey -Dictionary $Value -Key 'type' @commonParams) {
                    $entity['Runner'] = Resolve-JaxRunnerName -Name $Value['type'] @commonParams
                } elseif (Test-JaxDictionaryHasKey -Dictionary $Value -Key 'script' @commonParams) {
                    $entity['Runner'] = Resolve-JaxScriptRunnerName -ScriptPath $Value['script'] @commonParams
                }

                if (Test-JaxDictionaryHasKey -Dictionary $Value -Key 'tasks' @commonParams) {
                    $tasks = $Value['tasks']
                    if ($tasks -is [string]) {
                        $entity['Tasks'] = @($tasks)
                    } else {
                        $entity['Tasks'] = @($tasks)
                    }
                }
                if (Test-JaxDictionaryHasKey -Dictionary $Value -Key 'task' @commonParams) {
                    $entity['Tasks'] = @($Value['task'])
                }
                if (Test-JaxDictionaryHasKey -Dictionary $Value -Key 'script' @commonParams) {
                    $entity['Script'] = $Value['script']
                }
                if (Test-JaxDictionaryHasKey -Dictionary $Value -Key 'args' @commonParams) {
                    $entity['Args'] = $Value['args']
                }
                if (Test-JaxDictionaryHasKey -Dictionary $Value -Key 'psakeFile' @commonParams) {
                    $entity['PsakeFile'] = $Value['psakeFile']
                }
                if (Test-JaxDictionaryHasKey -Dictionary $Value -Key 'container' @commonParams) {
                    $containerValue = $Value['container']
                    if ($containerValue -is [string]) {
                        $entity['Container'] = @{ image = $containerValue }
                    } else {
                        $entity['Container'] = $containerValue
                    }
                }

                # Handle 'steps' for scenarios (scenario runner)
                if (Test-JaxDictionaryHasKey -Dictionary $Value -Key 'steps' @commonParams) {
                    $rawSteps = $Value['steps']
                    if ($rawSteps -is [System.Collections.IDictionary]) {
                        # If mapped (keys=names), preserve enumeration order when possible
                        $stepNames = @()
                        foreach ($kv in $rawSteps.GetEnumerator()) {
                            $stepNames += [string]$kv.Key
                        }
                        $entity['Entities'] = @($stepNames)
                    } elseif ($rawSteps -is [System.Collections.IEnumerable] -and $rawSteps -isnot [string]) {
                        $entity['Entities'] = @($rawSteps)
                    } else {
                        $entity['Entities'] = @($rawSteps)
                    }

                    # Default to scenario runner if not explicit
                    if (-not $entity.Contains('Runner') -or [string]::IsNullOrWhiteSpace([string]$entity['Runner'])) {
                        $entity['Runner'] = 'scenario'
                    }
                }

                # Normalize: if runner is psake and PsakeFile is not set but Script is, use Script as PsakeFile
                if ($entity.Contains('Runner') -and $entity['Runner'] -eq 'psake' -and -not $entity['PsakeFile'] -and $entity['Script']) {
                    $entity['PsakeFile'] = $entity['Script']
                }

                return (Set-JaxDiscoveredEntityDefaults -Entity $entity -Context $Context)
            }
        }
    }

    if ($existingNames -notcontains 'string') {
        $script:JaxScenarioResolvers += [pscustomobject]@{
            Name    = 'string'
            Order   = 10
            Handler = {
                [CmdletBinding()]
                param($Key, $Value, $ScenarioName, $ProvenancePath, $Context)

                $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
                Write-Debug "RESOLVER: string Key: $Key"

                if ($Value -isnot [string]) {
                    return $null
                }

                $entity = New-JaxRunEntity -Key $Key -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath @commonParams
                $trimmed = $Value.Trim()
                $extension = [IO.Path]::GetExtension($trimmed).ToLowerInvariant()
                if (-not [string]::IsNullOrWhiteSpace($extension)) {
                    $entity['Runner'] = Resolve-JaxScriptRunnerName -ScriptPath $trimmed @commonParams
                    $entity['Script'] = $trimmed
                } else {
                    $entity['Runner'] = 'psake'
                    $entity['Tasks'] = @($Value)
                }
                return (Set-JaxDiscoveredEntityDefaults -Entity $entity -Context $Context @commonParams)
            }
        }
    }

    if ($existingNames -notcontains 'enumerable') {
        $script:JaxScenarioResolvers += [pscustomobject]@{
            Name    = 'enumerable'
            Order   = 20
            Handler = {
                [CmdletBinding()]
                param($Key, $Value, $ScenarioName, $ProvenancePath, $Context)

                $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
                Write-Debug "RESOLVER: enumerable Key: $Key"

                if ($Value -isnot [System.Collections.IEnumerable] -or $Value -is [string] -or $Value -is [System.Collections.IDictionary]) {
                    return $null
                }

                $entity = New-JaxRunEntity -Key $Key -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath @commonParams
                $entity['Runner'] = 'psake'
                $entity['Tasks'] = @($Value)
                return (Set-JaxDiscoveredEntityDefaults -Entity $entity -Context $Context @commonParams)
            }
        }
    }
}
