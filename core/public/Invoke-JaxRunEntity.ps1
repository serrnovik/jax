function Invoke-JaxRunEntity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Entity,
        [hashtable] $Context = @{},
        [switch] $Container,
        [switch] $Docker,
        [string] $ContainerImage
    )

    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($Entity['Key']) Runner=$($Entity['Runner'])"


    $commonParams = @{}
    if ($Context.ContainsKey('CommonParameters') -and $Context['CommonParameters'] -is [System.Collections.IDictionary]) {
        $commonParams = $Context['CommonParameters']
    } else {
        $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
        $Context['CommonParameters'] = $commonParams
    }

    if (-not $Entity.Contains('Runner')) {
        if ($Entity.Contains('Type')) {
            $Entity['Runner'] = Resolve-JaxRunnerName -Name $Entity['Type'] @commonParams
        } else {
            throw "Run entity missing 'Runner'."
        }
    }

    $runner = Resolve-JaxRunnerName -Name $Entity['Runner'] @commonParams
    $useContainer = $false

    if ($Container -or $Docker) {
        $Context['ForceContainer'] = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($ContainerImage)) {
        $Context['DefaultContainerImage'] = $ContainerImage
    }

    if ($Entity.Contains('Container') -and $null -ne $Entity['Container']) {
        $useContainer = $true
    }
    if ($Context.ContainsKey('ForceContainer') -and $Context['ForceContainer']) {
        $useContainer = $true
    }

    if ($useContainer) {
        $Entity['InnerRunner'] = $runner
        $runner = 'container'
    }

    $handler = Get-JaxRunner -Name $runner
    if (-not ($Context.ContainsKey('SuppressEntityBanner') -and $Context['SuppressEntityBanner'])) {
        Write-JaxRunEntityBanner -Entity $Entity -RunnerName $runner
    }

    # Best-effort tab title for the main entity (psake case is further enriched by TaskSetup inside the runner).
    # Safe in all environments — detector + try/catch guarantee no breakage.
    try {
        $key = Get-JaxRunEntityKey -Entity $Entity
        $envHint = $null
        $flowHint = $null
        if ($Context.ContainsKey('RunConfig') -and $Context['RunConfig']) {
            $rc = $Context['RunConfig']
            $envHint = $rc
            $flowHint = $rc
        }
        if ($Context.ContainsKey('SelectedEnv') -and $Context['SelectedEnv']) {
            if (-not $envHint) { $envHint = $Context['SelectedEnv'] }
        }
        $t = Get-JaxTabTitleForRun -EntityKey $key -EnvName $envHint -FlowName $flowHint
        if ($t) { Set-JaxTerminalTabTitle -Title $t }
    } catch {}

    Write-Debug ("Invoke-JaxRunEntity dispatch runner='{0}' entityKey='{1}'" -f $runner, $Entity['Key'])
    return & $handler $Entity $Context $commonParams
}
