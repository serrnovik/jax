function Convert-JaxScenarioItemToRunEntity {
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

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $resolvers = Get-JaxScenarioResolvers

    foreach ($resolver in $resolvers) {
        $result = & $resolver.Handler $Key $Value $ScenarioName $ProvenancePath $Context @commonParams
        if ($null -ne $result) {
            return $result
        }
    }

    return (New-JaxRunEntity -Key $Key -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath @commonParams)
}
