function Get-JaxScenarioEntityKeys {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $FlowConfig,
        [string] $Scenario,
        [string] $ProvenancePath,
        [hashtable] $Context = @{},
        [switch] $ExcludeScripts
    )

    $entities = Get-JaxScenarioRunEntities -FlowConfig $FlowConfig -Scenario $Scenario -Context $Context -ProvenancePath $ProvenancePath
    if ($null -eq $entities) {
        return @()
    }

    $keys = @()
    foreach ($entity in $entities) {
        if ($ExcludeScripts -and (Test-JaxRunEntityIsScript -Entity $entity)) {
            continue
        }
        $key = Get-JaxRunEntityKey -Entity $entity
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $keys += $key
        }
    }

    return @($keys | Sort-Object)
}
