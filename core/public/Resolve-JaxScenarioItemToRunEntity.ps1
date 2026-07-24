function Resolve-JaxScenarioItemToRunEntity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Key,
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Value,
        [string] $ScenarioName,
        [string] $ProvenancePath,
        [hashtable] $Context
    )

    return (Convert-JaxScenarioItemToRunEntity -Key $Key -Value $Value -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context)
}
