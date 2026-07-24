function Get-JaxDiscoveredRunEntities {
    [CmdletBinding()]
    param (
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [System.Collections.IDictionary] $Config,
        [string] $EnvDir,
        [switch] $NoTasksDiscovery,
        [switch] $NoScriptsDiscovery,
        [switch] $NoCache,
        [switch] $SkipEnvRoot
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if ($null -eq $Config) {
        $Config = Get-JaxConfig -RepoRoot $RepoRoot
    }

    $aliasesMap = $null
    if ($Config.Keys -contains 'aliases') {
        $aliasesMap = $Config['aliases']
    }

    $taskEntities = @()
    if (-not $NoTasksDiscovery) {
        $taskPaths = Get-JaxTaskSearchPaths -RepoRoot $RepoRoot -Config $Config -EnvDir $EnvDir -SkipEnvRoot:$SkipEnvRoot @commonParams
        $pattern = $null
        if ($Config.tasks -and $Config.tasks.psakeFilePattern) {
            $pattern = $Config.tasks.psakeFilePattern
        }
        $taskEntities = Get-JaxPsakeTaskEntities -DirPaths $taskPaths -FilePattern $pattern -TaskIgnoreList $Config.taskIgnoreList -AliasesMap $aliasesMap -NoCache:$NoCache @commonParams
    }

    $scriptEntities = @()
    if (-not $NoScriptsDiscovery) {
        $scriptPaths = Get-JaxScriptSearchPaths -RepoRoot $RepoRoot -Config $Config -EnvDir $EnvDir -SkipEnvRoot:$SkipEnvRoot @commonParams
        $scriptEntities = Get-JaxScriptEntities -DirPaths $scriptPaths -AliasesMap $aliasesMap -NoCache:$NoCache @commonParams
    }

    $libraryEntities = @()
    if (-not $SkipEnvRoot -and -not [string]::IsNullOrWhiteSpace($EnvDir)) {
        $libraryEntities = Get-JaxLibraryEntities -RepoRoot $RepoRoot -Config $Config -EnvDir $EnvDir -NoCache:$NoCache @commonParams
    }

    $combined = Merge-JaxRunEntityList -Base $taskEntities -Add $scriptEntities @commonParams
    return Merge-JaxRunEntityList -Base $combined -Add $libraryEntities @commonParams
}
