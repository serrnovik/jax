function Invoke-JaxEnvInit {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [string] $EnvRoot,
        [string] $Client,
        [string] $Env,
        [string] $DefaultFlow,
        [string[]] $AdditionalFlows,
        [switch] $IncludeJaxfile,
        [switch] $IncludeBobfile,
        [switch] $EnableVault,
        [switch] $EnableDotenv,
        [switch] $IncludeState,
        [System.Collections.Queue] $InputQueue
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $config = Get-JaxConfig -RepoRoot $RepoRoot -SkipUserConfig @commonParams

    if ([string]::IsNullOrWhiteSpace($EnvRoot)) {
        $EnvRoot = $config.envRoot
    }
    if ([string]::IsNullOrWhiteSpace($EnvRoot)) {
        $EnvRoot = 'env'
    }

    if ([string]::IsNullOrWhiteSpace($Client)) {
        $Client = Read-JaxPromptString -Prompt 'client name' -Default 'sample' -InputQueue $InputQueue
    }
    if ([string]::IsNullOrWhiteSpace($Client)) {
        throw 'Client name is required.'
    }

    if ([string]::IsNullOrWhiteSpace($Env)) {
        $Env = Read-JaxPromptString -Prompt 'env name' -Default 'dev' -InputQueue $InputQueue
    }
    if ([string]::IsNullOrWhiteSpace($Env)) {
        throw 'Env name is required.'
    }

    if ([string]::IsNullOrWhiteSpace($DefaultFlow)) {
        $DefaultFlow = Read-JaxPromptString -Prompt 'default flow name' -Default 'build' -InputQueue $InputQueue
    }
    if ([string]::IsNullOrWhiteSpace($DefaultFlow)) {
        throw 'Default flow name is required.'
    }

    $extraFlows = @()
    if ($null -ne $AdditionalFlows -and $AdditionalFlows.Count -gt 0) {
        $extraFlows = @($AdditionalFlows)
    } elseif (-not $PSBoundParameters.ContainsKey('AdditionalFlows')) {
        $extraFlows = Read-JaxPromptList -Prompt 'additional flows (comma-separated)' -Default @() -InputQueue $InputQueue
    }

    $flowNames = New-Object 'System.Collections.Generic.List[string]'
    foreach ($flow in @($DefaultFlow) + @($extraFlows)) {
        if ($null -eq $flow) {
            continue
        }
        $candidate = $flow.ToString().Trim()
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        if (-not $flowNames.Contains($candidate)) {
            $flowNames.Add($candidate) | Out-Null
        }
    }

    $flowDirName = $config.flowDirNames | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($flowDirName)) {
        $flowDirName = 'flows'
    }

    $scriptsDirName = $config.scripts.dirNames | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($scriptsDirName)) {
        $scriptsDirName = 'scripts'
    }

    $commonDirName = $config.commonDirName
    if ([string]::IsNullOrWhiteSpace($commonDirName)) {
        $commonDirName = 'common'
    }

    $scenarioLibDirName = $config.scenarioLibDirName
    if ([string]::IsNullOrWhiteSpace($scenarioLibDirName)) {
        $scenarioLibDirName = 'scenarios-lib'
    }

    $envRootPath = Join-Path $RepoRoot $EnvRoot
    $commonDir = Join-Path $envRootPath $commonDirName
    $clientDir = Join-Path $envRootPath $Client
    $clientCommonDir = Join-Path $clientDir $commonDirName
    $envDir = Join-Path $clientDir $Env

    $hierarchy = @($commonDir, $clientCommonDir, $envDir)
    foreach ($dir in $hierarchy) {
        if (-not (Test-Path -Path $dir -PathType Container)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        foreach ($sub in @($flowDirName, $scriptsDirName, $scenarioLibDirName)) {
            $subPath = Join-Path $dir $sub
            if (-not (Test-Path -Path $subPath -PathType Container)) {
                New-Item -ItemType Directory -Path $subPath -Force | Out-Null
            }
            $anchorPath = Join-Path $subPath '.gitkeep'
            if (-not (Test-Path -Path $anchorPath -PathType Leaf)) {
                [System.IO.File]::WriteAllText($anchorPath, '')
            }
        }
    }

    $flowDir = Join-Path $envDir $flowDirName
    $flowTaskMap = @{
        'build'   = @('Build', 'Test')
        'publish' = @('PublishZip', 'PublishNuget')
        'k8s'     = @('BuildImage', 'PushImage', 'DeployK8s')
    }

    $taskNames = New-Object 'System.Collections.Generic.List[string]'
    foreach ($flowName in $flowNames) {
        $fileName = "{0}.yml" -f $flowName
        $flowPath = Join-Path $flowDir $fileName
        if (-not (Test-Path -Path $flowPath -PathType Leaf)) {
            $lower = $flowName.ToLowerInvariant()
            $flowTasks = @()
            if ($flowTaskMap.ContainsKey($lower)) {
                $flowTasks = $flowTaskMap[$lower]
            } else {
                $safe = ($flowName -replace '[^\w]', '')
                if ([string]::IsNullOrWhiteSpace($safe)) {
                    $safe = 'Example'
                }
                $flowTasks = @("{0}Task" -f $safe)
            }
            $flowContent = @()
            $flowContent += 'suite:'
            $flowContent += '  scenarios:'
            $flowContent += '    default:'
            foreach ($task in $flowTasks) {
                $flowContent += "      - $task"
            }
            $flowContent -join "`n" | Set-Content -Path $flowPath -Encoding ascii
        }

        if ($flowTaskMap.ContainsKey($flowName.ToLowerInvariant())) {
            foreach ($task in $flowTaskMap[$flowName.ToLowerInvariant()]) {
                if (-not $taskNames.Contains($task)) {
                    $taskNames.Add($task) | Out-Null
                }
            }
        } else {
            $safe = ($flowName -replace '[^\w]', '')
            if ([string]::IsNullOrWhiteSpace($safe)) {
                $safe = 'Example'
            }
            $task = "{0}Task" -f $safe
            if (-not $taskNames.Contains($task)) {
                $taskNames.Add($task) | Out-Null
            }
        }
    }

    if ($taskNames.Count -eq 0) {
        $taskNames.Add('ExampleTask') | Out-Null
    }

    $psakeContent = @()
    $psakeContent += ("Task Default -Depends {0}" -f $taskNames[0])
    foreach ($task in $taskNames) {
        $psakeContent += ''
        $psakeContent += ("Task {0} {{" -f $task)
        $psakeContent += ("    Write-Host ""{0} task""" -f $task)
        $psakeContent += '}'
    }
    $psakePayload = $psakeContent -join "`n"

    foreach ($dir in $hierarchy) {
        $psakePath = Join-Path $dir 'psakefile.ps1'
        if (-not (Test-Path -Path $psakePath -PathType Leaf)) {
            $psakePayload | Set-Content -Path $psakePath -Encoding ascii
        }
    }

    $sampleLibPath = Join-Path (Join-Path $commonDir $scenarioLibDirName) 'sample.yml'
    if (-not (Test-Path -Path $sampleLibPath -PathType Leaf)) {
        @'
sample_task:
  runner: psake
  tasks:
    - Build
'@ | Set-Content -Path $sampleLibPath -Encoding ascii
    }

    if ($IncludeJaxfile) {
        $jaxfilePath = Join-Path $envDir 'jaxfile.yml'
        if (-not (Test-Path -Path $jaxfilePath -PathType Leaf)) {
            @'
module:
  tasks:
    ExampleTask:
      exampleParam: "value"
'@ | Set-Content -Path $jaxfilePath -Encoding ascii
        }
    }

    if ($IncludeBobfile) {
        $bobfilePath = Join-Path $envDir 'bobfile.yml'
        if (-not (Test-Path -Path $bobfilePath -PathType Leaf)) {
            @'
module:
  tasks:
    ExampleTask:
      exampleParam: "value"
'@ | Set-Content -Path $bobfilePath -Encoding ascii
        }
    }

    $enableVault = $EnableVault
    if (-not $PSBoundParameters.ContainsKey('EnableVault')) {
        $enableVault = Read-JaxPromptBool -Prompt 'Enable vault plugin scaffold?' -Default $false -InputQueue $InputQueue
    }

    $enableDotenv = $EnableDotenv
    if (-not $PSBoundParameters.ContainsKey('EnableDotenv')) {
        $enableDotenv = Read-JaxPromptBool -Prompt 'Enable dotenv plugin scaffold?' -Default $false -InputQueue $InputQueue
    }

    if ($enableVault -or $enableDotenv) {
        $repoConfigPath = Get-JaxRepoConfigPath -RepoRoot $RepoRoot
        $repoConfig = $null
        if (Test-Path -Path $repoConfigPath -PathType Leaf) {
            $repoConfig = Resolve-JaxConfigSection -Config (Read-JaxYaml -Path $repoConfigPath)
        }
        if ($null -eq $repoConfig) {
            $repoConfig = @{}
        }
        if (-not ($repoConfig.Contains('plugins') -and $repoConfig['plugins'] -is [System.Collections.IDictionary])) {
            $repoConfig['plugins'] = @{}
        }
        $plugins = $repoConfig['plugins']
        $effectivePlugins = $config['plugins']
        $plugins['enabled'] = if ($plugins.Contains('enabled')) {
            @($plugins['enabled'])
        } else {
            @($effectivePlugins['enabled'])
        }
        $plugins['disabled'] = if ($plugins.Contains('disabled')) {
            @($plugins['disabled'])
        } else {
            @($effectivePlugins['disabled'])
        }
        if (-not ($plugins.Contains('config') -and $plugins['config'] -is [System.Collections.IDictionary])) {
            $plugins['config'] = @{}
        }
        $pluginConfig = $plugins['config']

        if ($enableVault) {
            if (-not ($plugins['enabled'] -contains 'vault')) {
                $plugins['enabled'] = @($plugins['enabled']) + @('vault')
            }
            $plugins['disabled'] = @($plugins['disabled'] | Where-Object { $_ -ne 'vault' })
            if (-not ($pluginConfig.Contains('vault') -and $pluginConfig['vault'] -is [System.Collections.IDictionary])) {
                $pluginConfig['vault'] = @{}
            }
            $pluginConfig['vault']['enabled'] = $true

            $vaultSampleDir = Join-Path $RepoRoot 'configs/jax'
            if (-not (Test-Path -Path $vaultSampleDir -PathType Container)) {
                New-Item -ItemType Directory -Path $vaultSampleDir -Force | Out-Null
            }
            $vaultSamplePath = Join-Path $vaultSampleDir 'vault.sample.yml'
            if (-not (Test-Path -Path $vaultSamplePath -PathType Leaf)) {
                @'
vault:
  address: "https://vault.example.com"
  auth:
    method: "approle"
    roleId: "replace-me"
    secretId: "replace-me"
'@ | Set-Content -Path $vaultSamplePath -Encoding ascii
            }
        }

        if ($enableDotenv) {
            if (-not ($plugins['enabled'] -contains 'dotenv')) {
                $plugins['enabled'] = @($plugins['enabled']) + @('dotenv')
            }
            $plugins['disabled'] = @($plugins['disabled'] | Where-Object { $_ -ne 'dotenv' })
            if (-not ($pluginConfig.Contains('dotenv') -and $pluginConfig['dotenv'] -is [System.Collections.IDictionary])) {
                $pluginConfig['dotenv'] = @{}
            }
            $pluginConfig['dotenv']['enabled'] = $true
            if (-not $pluginConfig['dotenv'].Contains('files')) {
                $pluginConfig['dotenv']['files'] = @('.env')
            }

            $envPath = Join-Path $RepoRoot '.env'
            if (-not (Test-Path -Path $envPath -PathType Leaf)) {
                @'
# Example local env variables (do not commit this file)
EXAMPLE_FLAG=true
'@ | Set-Content -Path $envPath -Encoding ascii
            }

            $gitIgnorePath = Join-Path $RepoRoot '.gitignore'
            if (Test-Path -Path $gitIgnorePath -PathType Leaf) {
                $ignoreContent = Get-Content -Path $gitIgnorePath
                if ($ignoreContent -notcontains '.env') {
                    Add-Content -Path $gitIgnorePath -Value '.env'
                }
            }
        }

        # Persist the repository overrides plus the explicit plugin choice.
        # Do not expand the rest of the effective defaults into repo config.
        $payload = [ordered]@{ jax = $repoConfig }
        Write-JaxYaml -Path $repoConfigPath -InputObject $payload @commonParams

        $jaxDir = Join-Path $RepoRoot '.jax'
        if (-not (Test-Path -Path $jaxDir -PathType Container)) {
            New-Item -ItemType Directory -Path $jaxDir -Force | Out-Null
        }
        $jaxGitIgnore = Join-Path $jaxDir '.gitignore'
        if (-not (Test-Path -Path $jaxGitIgnore -PathType Leaf)) {
            @'
state.yml
logs/
'@ | Set-Content -Path $jaxGitIgnore -Encoding ascii
        }
    }

    $jaxDir = Join-Path $RepoRoot '.jax'
    if (-not (Test-Path -Path $jaxDir -PathType Container)) {
        New-Item -ItemType Directory -Path $jaxDir -Force | Out-Null
    }
    $jaxGitIgnore = Join-Path $jaxDir '.gitignore'
    if (-not (Test-Path -Path $jaxGitIgnore -PathType Leaf)) {
        @'
state.yml
logs/
'@ | Set-Content -Path $jaxGitIgnore -Encoding ascii
    }

    $createState = $IncludeState
    if (-not $PSBoundParameters.ContainsKey('IncludeState')) {
        $createState = Read-JaxPromptBool -Prompt 'Create .jax/state.yml with defaults?' -Default $false -InputQueue $InputQueue
    }
    if ($createState) {
        Update-JaxState -RepoRoot $RepoRoot -Updates @{} | Out-Null
    }

    return @{
        EnvDir  = $envDir
        FlowDir = $flowDir
        Flows   = @($flowNames)
    }
}
