function Resolve-JaxBobScenarioSteps {
    [CmdletBinding()]
    param (
        $Steps,
        [string] $ScenarioName,
        [string] $ProvenancePath,
        [hashtable] $Context,
        [int] $Depth = 20,
        [string[]] $Stack = @()
    )

    $entities = @()
    if ($Steps -is [System.Collections.IDictionary]) {
        foreach ($stepKey in $Steps.Keys) {
            $stepValue = $Steps[$stepKey]
            $entities += Resolve-JaxBobScenarioItemRecursive -Key $stepKey -Value $stepValue -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context -Depth $Depth -Stack $Stack -StepMode
        }
        return @($entities)
    }

    if ($Steps -is [System.Collections.IEnumerable] -and $Steps -isnot [string]) {
        $index = 0
        foreach ($item in $Steps) {
            if ($item -is [System.Collections.IDictionary] -and $item.Count -eq 1) {
                $stepKey = $item.Keys | Select-Object -First 1
                $stepValue = $item[$stepKey]
                $entities += Resolve-JaxBobScenarioItemRecursive -Key $stepKey -Value $stepValue -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context -Depth $Depth -Stack $Stack -StepMode
            } else {
                $entities += Resolve-JaxBobScenarioItemRecursive -Key ("step_{0}" -f $index) -Value $item -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context -Depth $Depth -Stack $Stack -StepMode
            }
            $index++
        }
        return @($entities)
    }

    throw 'Scenario steps must be a map or list.'
}
