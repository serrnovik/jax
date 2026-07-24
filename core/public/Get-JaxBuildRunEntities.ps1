function Get-JaxBuildRunEntities {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $FlowConfig,
        [System.Collections.IDictionary] $Config,
        [string] $ProvenancePath,
        [hashtable] $Context = @{}
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if (-not $FlowConfig.Contains('suite')) {
        return @()
    }

    $suite = $FlowConfig['suite']
    if ($suite -isnot [System.Collections.IDictionary]) {
        return @()
    }

    $buildSection = $null
    $buildSectionNames = Get-JaxBuildSectionNames -Config $Config
    foreach ($sectionName in $buildSectionNames) {
        if ($suite.Contains($sectionName)) {
            $buildSection = $suite[$sectionName]
            break
        }
    }

    if ($null -eq $buildSection) {
        return @()
    }

    $entities = @()
    if ($buildSection -is [System.Collections.IDictionary]) {
        foreach ($key in $buildSection.Keys) {
            $value = $buildSection[$key]
            $entity = Convert-JaxScenarioItemToRunEntity -Key $key -Value $value -ScenarioName 'build' -ProvenancePath $ProvenancePath -Context $Context
            Add-JaxScenarioEntities -Entities ([ref]$entities) -Result $entity
        }
        return @($entities)
    }

    if ($buildSection -is [System.Collections.IEnumerable] -and $buildSection -isnot [string]) {
        foreach ($item in $buildSection) {
            if ($item -is [string]) {
                $entity = Convert-JaxScenarioItemToRunEntity -Key $item -Value $item -ScenarioName 'build' -ProvenancePath $ProvenancePath -Context $Context
                Add-JaxScenarioEntities -Entities ([ref]$entities) -Result $entity
                continue
            }
            if ($item -is [System.Collections.IDictionary] -and $item.Count -eq 1) {
                $itemKey = $item.Keys | Select-Object -First 1
                $entity = Convert-JaxScenarioItemToRunEntity -Key $itemKey -Value $item[$itemKey] -ScenarioName 'build' -ProvenancePath $ProvenancePath -Context $Context
                Add-JaxScenarioEntities -Entities ([ref]$entities) -Result $entity
                continue
            }
            $entity = Convert-JaxScenarioItemToRunEntity -Key 'build' -Value $item -ScenarioName 'build' -ProvenancePath $ProvenancePath -Context $Context
            Add-JaxScenarioEntities -Entities ([ref]$entities) -Result $entity
        }
        return @($entities)
    }

    $entity = Convert-JaxScenarioItemToRunEntity -Key 'build' -Value $buildSection -ScenarioName 'build' -ProvenancePath $ProvenancePath -Context $Context
    Add-JaxScenarioEntities -Entities ([ref]$entities) -Result $entity
    return @($entities)
}
