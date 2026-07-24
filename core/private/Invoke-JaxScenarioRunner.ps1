function Invoke-JaxScenarioRunner {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Entity,
        [hashtable] $Context = @{},
        [hashtable] $CommonParameters = @{}
    )

    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($Entity['Key'])"

    $expanded = Expand-JaxScenarioEntity -Entity $Entity -Context $Context -InheritedArgs @{} @CommonParameters
    return Invoke-JaxRunEntities -Entities $expanded -Context $Context @CommonParameters
}
