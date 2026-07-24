function Add-JaxScenarioEntities {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ref] $Entities,
        $Result
    )

    if ($null -eq $Result) {
        return
    }

    if ($Result -is [System.Collections.IEnumerable] -and $Result -isnot [string] -and $Result -isnot [System.Collections.IDictionary]) {
        foreach ($item in $Result) {
            Add-JaxScenarioEntities -Entities $Entities -Result $item
        }
        return
    }

    $Entities.Value += ,$Result
}
