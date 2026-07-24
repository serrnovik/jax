function Invoke-JaxRunEntities {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable] $Entities,
        [hashtable] $Context = @{},
        [switch] $Container,
        [switch] $Docker,
        [string] $ContainerImage,
        [string[]] $Override,
        [string[]] $Overrides
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if (-not ($Context.ContainsKey('CommonParameters') -and $Context['CommonParameters'] -is [System.Collections.IDictionary])) {
        $Context['CommonParameters'] = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    }

    if (-not ($Context.ContainsKey('RepoRoot') -and -not [string]::IsNullOrWhiteSpace($Context['RepoRoot']))) {
        $Context['RepoRoot'] = Get-JaxRepoRoot @commonParams
    }

    # Core feature: git root should be available to psake tasks via $properties.env.git.root
    $corePsakeProps = @{
        env = @{
            git = @{
                root = $Context['RepoRoot']
            }
        }
    }
    $existingPsakeProps = @{}
    if ($Context.ContainsKey('PsakeProperties') -and $Context['PsakeProperties'] -is [System.Collections.IDictionary]) {
        $existingPsakeProps = $Context['PsakeProperties']
    }
    $Context['PsakeProperties'] = Merge-JaxHashtable -Base $corePsakeProps -Overlay $existingPsakeProps

    if ($Container -or $Docker) {
        $Context['ForceContainer'] = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($ContainerImage)) {
        $Context['DefaultContainerImage'] = $ContainerImage
    }
    if ($null -ne $Override -and $Override.Count -gt 0) {
        $Context['Override'] = $Override
    }
    if ($null -ne $Overrides -and $Overrides.Count -gt 0) {
        $Context['Overrides'] = $Overrides
    }
    if (-not ($Context.ContainsKey('SkipPlugins') -and $Context['SkipPlugins'])) {
        if (-not $Context.ContainsKey('AllowAutoPluginLoad')) {
            $Context['AllowAutoPluginLoad'] = $true
        }
        if ($Context['AllowAutoPluginLoad'] -and (-not $Context.ContainsKey('RepoRoot') -or [string]::IsNullOrWhiteSpace($Context['RepoRoot']))) {
            $Context['RepoRoot'] = Get-JaxRepoRoot
        }
    }

    Invoke-JaxHooks -Name 'BeforeRunEntities' -Context $Context -Data @{
        Entities = $Entities
    }

    $results = @()
    try {
        foreach ($entity in $Entities) {
            if ($null -eq $entity) {
                continue
            }
            Invoke-JaxHooks -Name 'BeforeRunEntity' -Context $Context -Data @{
                Entity = $entity
            }
            $entityOutput = @()
            Invoke-JaxRunEntity -Entity $entity -Context $Context | ForEach-Object {
                $entityOutput += $_
                $_
            }
            if ($entityOutput.Count -gt 0) {
                $results += ,$entityOutput
            } else {
                $results += ,$null
            }
            Invoke-JaxHooks -Name 'AfterRunEntity' -Context $Context -Data @{
                Entity = $entity
            }
        }
    }
    finally {
        # Extra safety net: if someone calls Invoke-JaxRunEntities directly (tests, plugins, etc.)
        # we still finalize the tab title on the way out (no-ops if the inner runner
        # already did, or if no title was ever set).
        try {
            Complete-JaxTerminalTitle
        } catch {}
    }

    Invoke-JaxHooks -Name 'AfterRunEntities' -Context $Context -Data @{
        Entities = $Entities
        Results  = $results
    }

    if ($Context.ContainsKey('SuppressResults') -and $Context['SuppressResults']) {
        return
    }

    return $results
}
