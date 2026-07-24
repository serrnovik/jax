function Invoke-JaxContainerRunner {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Entity,
        [hashtable] $Context = @{},
        [hashtable] $CommonParameters = @{}
    )

    $vaultTainted = $Context.ContainsKey('VaultSecretsResolved') -and [bool]$Context['VaultSecretsResolved']
    $debugImage = if ($vaultTainted) { '<redacted>' } else { $Entity['Container']['image'] }
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($Entity['Key']) Image=$debugImage"

    $containerConfig = $Entity['Container']
    $image = $null
    if ($containerConfig -is [System.Collections.IDictionary] -and $containerConfig.Contains('image')) {
        $image = $containerConfig['image']
    }
    if ([string]::IsNullOrWhiteSpace($image) -and $Context.ContainsKey('ModuleDockerImage')) {
        $image = $Context['ModuleDockerImage']
    }
    if ([string]::IsNullOrWhiteSpace($image) -and $Context.ContainsKey('DefaultContainerImage')) {
        $image = $Context['DefaultContainerImage']
    }
    if ([string]::IsNullOrWhiteSpace($image)) {
        throw "Container runner requires an image (container.image or module.docker.image)."
    }

    $repoRoot = $Context['RepoRoot']
    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        $repoRoot = Get-JaxRepoRoot @CommonParameters
    }

    $mounts = @()
    $mounts += "${repoRoot}:/jax/src"
    if ($containerConfig -is [System.Collections.IDictionary] -and $containerConfig.Contains('mounts')) {
        $mounts += @($containerConfig['mounts'])
    }

    $envVars = @()
    if ($containerConfig -is [System.Collections.IDictionary] -and $containerConfig.Contains('env')) {
        $envVars += @($containerConfig['env'])
    }
    if (Test-Path Env:VAULT_ADDR) {
        $envVars += @("VAULT_ADDR=$((Get-ChildItem -Path Env:VAULT_ADDR).Value)")
    }

    $innerRunner = $Entity['InnerRunner']
    if ([string]::IsNullOrWhiteSpace($innerRunner)) {
        $innerRunner = $Entity['Runner']
    }
    $innerRunner = Resolve-JaxRunnerName -Name $innerRunner @CommonParameters

    $containerCommand = @()
    if ($innerRunner -in @('script', 'pwshscript')) {
        $scriptPath = Resolve-JaxContainerPath -HostPath $Entity['Script'] -RepoRoot $repoRoot @CommonParameters
        $containerCommand = @('pwsh', '-NoProfile', '-File', $scriptPath)
        $entityArgs = $Entity['Args']
        if ($entityArgs -is [System.Collections.IDictionary]) {
            foreach ($key in $entityArgs.Keys) {
                $value = $entityArgs[$key]
                if ($value -is [bool]) {
                    if ($value) { $containerCommand += "-$key" }
                    continue
                }
                $containerCommand += "-$key"
                $containerCommand += [string]$value
            }
        } elseif ($entityArgs -is [System.Collections.IEnumerable] -and $entityArgs -isnot [string]) {
            $containerCommand += @($entityArgs | ForEach-Object { [string]$_ })
        }
    } elseif ($innerRunner -eq 'psake') {
        $buildFile = $Entity['PsakeFile']
        if ([string]::IsNullOrWhiteSpace($buildFile) -and $Context.ContainsKey('PsakeFile')) {
            $buildFile = $Context['PsakeFile']
        }
        if ([string]::IsNullOrWhiteSpace($buildFile)) {
            throw "Container psake runner requires 'PsakeFile' (entity or context)."
        }
        $buildFile = Resolve-JaxContainerPath -HostPath $buildFile -RepoRoot $repoRoot @CommonParameters
        $taskList = @()
        if ($Entity.Contains('Tasks') -and $null -ne $Entity['Tasks']) {
            $taskList = @($Entity['Tasks'])
        }
        $escapedBuildFile = ([string]$buildFile).Replace("'", "''")
        $escapedTasks = @($taskList | ForEach-Object { ([string]$_).Replace("'", "''") })
        $taskListLiteral = if ($escapedTasks.Count -gt 0) { "@('" + ($escapedTasks -join "','") + "')" } else { '@()' }
        $psakeCommand = "Import-Module psake; Invoke-psake -buildFile '$escapedBuildFile' -taskList $taskListLiteral -nologo"
        $containerCommand = @('pwsh', '-NoProfile', '-Command', $psakeCommand)
    } else {
        throw "Unsupported inner runner for container execution: '$innerRunner'."
    }

    $dockerArgs = @('run', '--rm')
    foreach ($mount in $mounts) {
        $dockerArgs += @('-v', [string]$mount)
    }
    foreach ($envVar in $envVars) {
        $dockerArgs += @('-e', [string]$envVar)
    }
    $dockerArgs += [string]$image
    $dockerArgs += $containerCommand

    function Format-JaxContainerDisplayArgument {
        param([AllowEmptyString()] [string] $Value)

        if ($Value -notmatch '[\s''"]') { return $Value }
        return "'" + $Value.Replace("'", "''") + "'"
    }

    $displayArgs = @('run', '--rm')
    foreach ($mount in $mounts) {
        $displayMount = if ($vaultTainted) { '<redacted>' } else { Format-JaxContainerDisplayArgument ([string]$mount) }
        $displayArgs += @('-v', $displayMount)
    }
    foreach ($envVar in $envVars) {
        $envName = ([string]$envVar -split '=', 2)[0]
        $displayArgs += @('-e', "${envName}=<redacted>")
    }
    if ($vaultTainted) {
        $displayArgs += '<image redacted>'
        $displayArgs += '<arguments redacted>'
    } else {
        $displayArgs += Format-JaxContainerDisplayArgument ([string]$image)
        $displayArgs += @($containerCommand | ForEach-Object { Format-JaxContainerDisplayArgument ([string]$_) })
    }
    $dockerCommandDisplay = 'docker ' + ($displayArgs -join ' ')

    if ($Context['DryRun']) {
        return $dockerCommandDisplay
    }

    $imageDisplay = if ($vaultTainted) { '<redacted>' } else { $image }
    Write-Host "🐳 Running in container: $imageDisplay"
    Write-Host "🧷 docker run: $dockerCommandDisplay"
    & docker @dockerArgs
}
