function Resolve-JaxBobScenarioItemRecursive {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Key,
        [AllowNull()]
        $Value,
        [string] $ScenarioName,
        [string] $ProvenancePath,
        [hashtable] $Context,
        [int] $Depth = 20,
        [string[]] $Stack = @(),
        [switch] $StepMode,
        [switch] $IsLibraryItem
    )

    if ($Depth -le 0) {
        throw "Max recursion depth reached while expanding scenario item '$Key'."
    }

    $library = $null
    if ($null -ne $Context -and $Context.ContainsKey('ScenarioLibrary')) {
        $library = $Context['ScenarioLibrary']
    }

    if ($null -eq $Value) {
        if ($null -eq $library -or $library -isnot [System.Collections.IDictionary]) {
            throw "Scenario item '$Key' references a library item, but no library is available."
        }
        if (-not $library.Contains($Key)) {
            throw "Library item '$Key' not found in scenarios-lib or suite.library."
        }
        if ($Stack -contains $Key) {
            throw "Recursive library reference detected: $($Stack -join ' -> ') -> $Key"
        }
        $nextStack = @($Stack + $Key)
        return Resolve-JaxBobScenarioItemRecursive -Key $Key -Value $library[$Key] -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context -Depth ($Depth - 1) -Stack $nextStack -StepMode:$StepMode -IsLibraryItem
    }

    if ($Value -is [System.Collections.IDictionary] -and $Value.Contains('steps')) {
        return Resolve-JaxBobScenarioSteps -Steps $Value['steps'] -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context -Depth ($Depth - 1) -Stack $Stack
    }

    if (($IsLibraryItem -or $StepMode) -and $Value -is [System.Collections.IEnumerable] -and $Value -isnot [string] -and $Value -isnot [System.Collections.IDictionary]) {
        return Resolve-JaxBobScenarioSteps -Steps $Value -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context -Depth ($Depth - 1) -Stack $Stack
    }

    if ($StepMode -and $Value -is [string] -and $library -and $library -is [System.Collections.IDictionary] -and $library.Contains($Value)) {
        if ($Stack -contains $Value) {
            throw "Recursive library reference detected: $($Stack -join ' -> ') -> $Value"
        }
        $nextStack = @($Stack + $Value)
        return Resolve-JaxBobScenarioItemRecursive -Key $Value -Value $library[$Value] -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context -Depth ($Depth - 1) -Stack $nextStack -StepMode -IsLibraryItem
    }

    # In StepMode, a string step value can be a reference to another scenario item in the same scenario config.
    # Prefer resolving it before treating it as a raw psake task name.
    if ($StepMode -and $Value -is [string] -and $null -ne $Context -and $Context.ContainsKey('ScenarioItemDefinitions') -and $Context['ScenarioItemDefinitions'] -is [System.Collections.IDictionary]) {
        $defs = $Context['ScenarioItemDefinitions']
        if ($defs.Contains($Value) -and $null -ne $defs[$Value]) {
            $scenarioRef = "scenario:$Value"
            if ($Stack -contains $scenarioRef) {
                throw "Recursive scenario reference detected: $($Stack -join ' -> ') -> $scenarioRef"
            }
            $nextStack = @($Stack + $scenarioRef)
            return Resolve-JaxBobScenarioItemRecursive -Key $Value -Value $defs[$Value] -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context -Depth ($Depth - 1) -Stack $nextStack -StepMode -IsLibraryItem:$IsLibraryItem
        }
    }

    # In StepMode, a string step value can be a reference to a scenario-defined entity (not a psake task name).
    # Prefer resolving it via ScenarioEntityIndex when available so args (e.g. stepName) and runner/script/task
    # definitions are preserved. Fallback to normal string handling when not found.
    if ($StepMode -and $Value -is [string] -and $null -ne $Context -and $Context.ContainsKey('ScenarioEntityIndex') -and $Context['ScenarioEntityIndex'] -is [System.Collections.IDictionary]) {
        $idx = $Context['ScenarioEntityIndex']
        $normalized = Convert-JaxRunEntityName -Name $Value
        $resolved = $null
        if (-not [string]::IsNullOrWhiteSpace($normalized) -and $idx.ContainsKey($normalized)) {
            $resolved = $idx[$normalized]
        } elseif ($idx.ContainsKey($Value)) {
            $resolved = $idx[$Value]
        }
        if ($resolved -is [System.Collections.IDictionary]) {
            return @($resolved)
        }
    }

    $entity = Resolve-JaxScenarioItemToRunEntity -Key $Key -Value $Value -ScenarioName $ScenarioName -ProvenancePath $ProvenancePath -Context $Context
    if ($null -eq $entity) {
        return @()
    }

    return @($entity)
}
