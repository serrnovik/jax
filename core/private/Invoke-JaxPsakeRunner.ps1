function Invoke-JaxPsakeRunner {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Entity,
        [hashtable] $Context = @{},
        [hashtable] $CommonParameters = @{}
    )

    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($Entity['Key']) Psake=$($Entity['PsakeFile'])"

    Initialize-JaxPsakeProvider -RepoRoot $Context['RepoRoot'] @CommonParameters

    $buildFile = $Entity['PsakeFile']
    if ([string]::IsNullOrWhiteSpace($buildFile) -and $Context.ContainsKey('PsakeFile')) {
        $buildFile = $Context['PsakeFile']
    }
    if ([string]::IsNullOrWhiteSpace($buildFile)) {
        throw "Psake runner requires 'PsakeFile' (entity or context)."
    }

    $buildFile = Resolve-JaxRepoRootedPath -Path $buildFile -RepoRoot $Context['RepoRoot'] -WorkingDir $Context['WorkingDir'] @CommonParameters

    $taskList = @()
    if ($Entity.Contains('Tasks') -and $null -ne $Entity['Tasks']) {
        $tasks = $Entity['Tasks']
        if ($tasks -is [string]) {
            $taskList = @($tasks)
        } else {
            $taskList = @($tasks)
        }
    }

    $properties = @{}
    $baseProps = $null
    if ($Context.ContainsKey('PsakeProperties') -and $Context['PsakeProperties'] -is [System.Collections.IDictionary]) {
        if ($null -eq $baseProps) {
            $baseProps = $Context['PsakeProperties']
        } else {
            $baseProps = Merge-JaxHashtable -Base $baseProps -Overlay $Context['PsakeProperties'] @CommonParameters
        }
    }
    if ($Context.ContainsKey('RunConfig') -and $Context['RunConfig'] -is [System.Collections.IDictionary]) {
        if ($null -eq $baseProps) {
            $baseProps = $Context['RunConfig']
        } else {
            # precedence: psake properties override run-config defaults
            $baseProps = Merge-JaxHashtable -Base $Context['RunConfig'] -Overlay $baseProps @CommonParameters
        }
    }
    if ($null -ne $baseProps) {
        $properties = Merge-JaxHashtable -Base @{} -Overlay $baseProps @CommonParameters
    }
    if ($Entity['Args'] -is [System.Collections.IDictionary]) {
        $properties = Merge-JaxHashtable -Base $properties -Overlay $Entity['Args'] @CommonParameters
    }
    # CLI DynamicParam-bound task params: apply last (highest precedence)
    if ($Context.ContainsKey('CliArgs') -and $Context['CliArgs'] -is [System.Collections.IDictionary]) {
        $properties = Merge-JaxHashtable -Base $properties -Overlay $Context['CliArgs'] @CommonParameters
    }

    $taskListDisplay = if ($taskList.Count -gt 0) { $taskList -join ', ' } else { '<default>' }
    $commandPreview = "Invoke-psake -buildFile `"$buildFile`" -taskList @('$taskListDisplay')"

    if ($Context['DryRun']) {
        return $commandPreview
    }

    $repoRoot = $Context['RepoRoot']
    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        $repoRoot = Get-JaxRepoRoot @CommonParameters
    }
    if (-not [string]::IsNullOrWhiteSpace($repoRoot)) {
        $propertiesForLog = $properties
        if ($Context.ContainsKey('VaultSecretsResolved') -and [bool]$Context['VaultSecretsResolved']) {
            $propertiesForLog = '[redacted: Vault-resolved properties]'
        }
        $payload = @{
            buildFile  = $buildFile
            taskList   = $taskList
            properties = $propertiesForLog
        }
        $safePayload = Convert-JaxToJsonSafeValue -Value $payload -MaxDepth 40 @CommonParameters
        $logPath = Write-JaxLogFile -Content ($safePayload | ConvertTo-Json -Depth 40) -Category 'psake-params' -Extension 'json' -RepoRoot $repoRoot @CommonParameters
        Write-Host ("🪵 → 🧾 Psake params saved: {0}" -f (Format-JaxPathLink -Path $logPath @CommonParameters))
    }

    if ($Context.ContainsKey('RunConfigPath') -and -not [string]::IsNullOrWhiteSpace($Context['RunConfigPath'])) {
        Write-Host ("🔍 Run config: {0}" -f (Format-JaxPathLink -Path $Context['RunConfigPath'] @CommonParameters))
    }
    if ($taskList.Count -gt 0) {
        Write-JaxConsoleLine -Text "🔥 Executing task " -Color 'DarkGray' -NoNewline @CommonParameters
        Write-JaxConsoleLine -Text ("'{0}'" -f ($taskList -join ', ')) -Color 'DeepSkyBlue' @CommonParameters
    }
    Write-Host "🪵 → 🍵 Invoking psake with these parameters."
    Write-Host ("🚀 Invoking psake: {0}" -f (Format-JaxPathLink -Path $buildFile @CommonParameters))

    # --- Terminal tab title integration (Ghostty/cmux only, zero impact elsewhere) ---
    $mainTaskForTitle = if ($taskList.Count -gt 0) { $taskList[0] } else { [string]$Entity['Key'] }
    $envForTitle = $null
    $flowForTitle = $null
    try {
        # Try several sources for a clean env/flow name. The formatter also normalizes aggressively now.
        $candidates = @()

        if ($Context.ContainsKey('RunConfig') -and $Context['RunConfig']) {
            $candidates += $Context['RunConfig']
        }
        if ($properties -and $properties.Contains('env')) {
            $candidates += $properties['env']
        }
        if ($properties -and $properties.Contains('flow')) {
            $candidates += $properties['flow']
        }
        if ($Context.ContainsKey('SelectedEnv') -and $Context['SelectedEnv']) {
            $candidates += $Context['SelectedEnv']
        }

        foreach ($c in $candidates) {
            if (-not $envForTitle) {
                if ($c -is [System.Collections.IDictionary]) {
                    if ($c.Contains('name')) { $envForTitle = $c['name'] }
                    elseif ($c.Contains('env')) { $envForTitle = $c['env'] }
                } elseif ($c.PSObject) {
                    if ($c.PSObject.Properties.Match('Name').Count -gt 0) { $envForTitle = [string]$c.Name }
                    elseif ($c.PSObject.Properties.Match('name').Count -gt 0) { $envForTitle = [string]$c.name }
                }
            }
            if (-not $flowForTitle) {
                if ($c -is [System.Collections.IDictionary]) {
                    if ($c.Contains('flow')) { $flowForTitle = $c['flow'] }
                    elseif ($c.Contains('configuration')) { $flowForTitle = $c['configuration'] }
                } elseif ($c.PSObject) {
                    if ($c.PSObject.Properties.Match('Flow').Count -gt 0) { $flowForTitle = [string]$c.Flow }
                    elseif ($c.PSObject.Properties.Match('Configuration').Count -gt 0) { $flowForTitle = [string]$c.Configuration }
                }
            }
        }
    } catch {}

    # Set title for the outer psake task immediately
    try {
        $outerTitle = Get-JaxTabTitleForRun -EntityKey $mainTaskForTitle -EnvName $envForTitle -FlowName $flowForTitle
        if ($outerTitle) { Set-JaxTerminalTabTitle -Title $outerTitle }
    } catch {}

    # Register a TaskSetup so every inner psake task ("EnsureFlutter", "RestoreFlutterApp", etc.)
    # updates the tab title in supported terminals. This is the key UX the user asked for.
    try {
        $titleEnv = $envForTitle
        $titleFlow = $flowForTitle
        $titleMain = $mainTaskForTitle

        TaskSetup {
            param($task)
            try {
                $inner = ''
                if ($null -ne $task) {
                    if ($task.PSObject.Properties.Match('Name').Count -gt 0) {
                        $inner = [string]$task.Name
                    } elseif ($task -is [string]) {
                        $inner = $task
                    }
                }
                if ([string]::IsNullOrWhiteSpace($inner) -and $psake -and $psake.context -and $psake.context.Count -gt 0) {
                    $peek = $psake.context.Peek()
                    if ($peek -and $peek.PSObject.Properties.Match('currentTaskName').Count -gt 0) {
                        $inner = [string]$peek.currentTaskName
                    }
                }
                $t = Get-JaxTabTitleForRun -EntityKey $titleMain -EnvName $titleEnv -FlowName $titleFlow -CurrentPsakeTask $inner
                if ($t) { Set-JaxTerminalTabTitle -Title $t }
            } catch {
                # never break a build because of title
            }
        }
    } catch {
        # If TaskSetup registration fails for any reason (old psake, scope, etc.) we just skip titles for inner tasks.
    }

    # IMPORTANT:
    # psake uses an internal variable named `$module` during initialization:
    #   . $module $initialization
    # If we pass a property key named `module`, psake will create a variable `$module` (from -properties)
    # and clobber its internal `$module`, breaking initialization.
    #
    # But our tasks rely on `$properties.module.*` heavily.
    # Solution: temporarily move `module` to a safe key so psake won't create `$module`,
    # then re-inject it AFTER psake initialization via the -initialization hook.
    $psakePropertiesObject = $properties
    $initialization = $null

    $originalModuleKey = $null
    if ($psakePropertiesObject -is [System.Collections.IDictionary]) {
        foreach ($k in @($psakePropertiesObject.Keys)) {
            if ($null -eq $k) {
                continue
            }
            if (([string]$k).ToLowerInvariant() -eq 'module') {
                $originalModuleKey = [string]$k
                break
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($originalModuleKey)) {
        $moduleKey = '__jax_module'
        $hasInternalKey = $false
        foreach ($k in @($psakePropertiesObject.Keys)) {
            if ($null -ne $k -and ([string]$k).ToLowerInvariant() -eq $moduleKey) {
                $hasInternalKey = $true
                break
            }
        }
        if ($hasInternalKey) {
            throw "Invoke-JaxPsakeRunner: internal key collision: properties already contains '$moduleKey'."
        }

        $psakePropertiesObject[$moduleKey] = $psakePropertiesObject[$originalModuleKey]
        $psakePropertiesObject.Remove($originalModuleKey) | Out-Null
        $initialization = {
            # restore module tree for tasks (after psake init)
            $hasModule = $false
            foreach ($k in @($properties.Keys)) {
                if ($null -ne $k -and ([string]$k).ToLowerInvariant() -eq 'module') {
                    $hasModule = $true
                    break
                }
            }
            if (-not $hasModule -and $properties -is [System.Collections.IDictionary] -and $properties.Keys -contains '__jax_module') {
                $properties['module'] = $properties['__jax_module']
                $properties.Remove('__jax_module') | Out-Null
            }
        }
    }
    # Wrap the actual psake invocation so that even if a task throws, the build aborts,
    # or the user hits Ctrl-C, we finalize the tab title. On finish we leave the last
    # task on the tab stamped with ✓ (success) or ✗ (failure) rather than restoring the
    # pre-jax label. The catch only flags failure (so the finally picks ✗) and rethrows.
    try {
        if ($taskList.Count -gt 0) {
            if ($null -ne $initialization) {
                return Invoke-psake -buildFile $buildFile -taskList $taskList -properties $psakePropertiesObject -initialization $initialization -nologo @CommonParameters
            }
            return Invoke-psake -buildFile $buildFile -taskList $taskList -properties $psakePropertiesObject -nologo @CommonParameters
        }

        if ($null -ne $initialization) {
            return Invoke-psake -buildFile $buildFile -properties $psakePropertiesObject -initialization $initialization -nologo @CommonParameters
        }
        return Invoke-psake -buildFile $buildFile -properties $psakePropertiesObject -nologo @CommonParameters
    }
    catch {
        $script:JaxTitleRunFailed = $true
        throw
    }
    finally {
        try {
            Complete-JaxTerminalTitle
        } catch {}
    }
}
