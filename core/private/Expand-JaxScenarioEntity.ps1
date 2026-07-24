function Expand-JaxScenarioEntity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Entity,
        [hashtable] $Context = @{},
        [System.Collections.IDictionary] $InheritedArgs = @{},
        [int] $Depth = 20
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters

    if ($Depth -le 0) {
        throw "Max recursion depth reached while expanding scenario entity '$($Entity['Key'])'."
    }

    $runner = $null
    if ($Entity.Contains('Runner') -and -not [string]::IsNullOrWhiteSpace([string]$Entity['Runner'])) {
        $runner = Resolve-JaxRunnerName -Name ([string]$Entity['Runner']) @commonParams
    }

    $entityArgs = @{}
    if ($Entity.Contains('Args') -and $Entity['Args'] -is [System.Collections.IDictionary]) {
        $entityArgs = $Entity['Args']
    }

    $cliArgs = @{}
    if ($Context.ContainsKey('CliArgs') -and $Context['CliArgs'] -is [System.Collections.IDictionary]) {
        $cliArgs = $Context['CliArgs']
    }

    # Base args (from parent sceny) should be lower-precedence than entity args.
    $effectiveArgs = @{}
    if ($InheritedArgs -and $InheritedArgs.Count -gt 0) {
        $effectiveArgs = Merge-JaxHashtable -Base $effectiveArgs -Overlay $InheritedArgs @commonParams
    }
    if ($entityArgs -and $entityArgs.Count -gt 0) {
        $effectiveArgs = Merge-JaxHashtable -Base $effectiveArgs -Overlay $entityArgs @commonParams
    }
    # CLI args should win over scenario/entity args (mirrors runner behavior).
    if ($cliArgs -and $cliArgs.Count -gt 0) {
        $effectiveArgs = Merge-JaxHashtable -Base $effectiveArgs -Overlay $cliArgs @commonParams
    }

    if ($runner -ne 'scenario') {
        # Shallow clone entity so we never mutate discovered entities in-place.
        $clone = [ordered]@{}
        foreach ($k in $Entity.Keys) {
            $clone[$k] = $Entity[$k]
        }
        if ($effectiveArgs.Count -gt 0) {
            $clone['Args'] = $effectiveArgs
        }
        return @($clone)
    }

    # Scenario: expand children and flatten.
    $rawChildren = @()
    if ($Entity.Contains('Entities') -and $null -ne $Entity['Entities']) {
        $rawChildren = @($Entity['Entities'])
    }
    if ($rawChildren.Count -eq 0) {
        return @()
    }

    $result = @()
    foreach ($child in $rawChildren) {
        $childEntity = $null
        if ($child -is [System.Collections.IDictionary]) {
            $childEntity = $child
        } elseif ($child -is [string]) {
            $lookup = $null
            # Prefer scenario-defined entities (so scenario args like stepName are preserved),
            # then fall back to discovered tasks/scripts.
            if ($Context.ContainsKey('ScenarioEntityIndex') -and $Context['ScenarioEntityIndex'] -is [System.Collections.IDictionary]) {
                $index = $Context['ScenarioEntityIndex']
                $normalized = Convert-JaxRunEntityName -Name $child @commonParams
                if ($index.ContainsKey($normalized)) {
                    $lookup = $index[$normalized]
                } elseif ($index.ContainsKey($child)) {
                    $lookup = $index[$child]
                }
            }
            if ($Context.ContainsKey('DiscoveredEntityIndex') -and $Context['DiscoveredEntityIndex'] -is [System.Collections.IDictionary]) {
                $index = $Context['DiscoveredEntityIndex']
                $normalized = Convert-JaxRunEntityName -Name $child @commonParams
                if ($null -eq $lookup -and $index.ContainsKey($normalized)) {
                    $lookup = $index[$normalized]
                } elseif ($null -eq $lookup -and $index.ContainsKey($child)) {
                    $lookup = $index[$child]
                }
            }
            if ($null -ne $lookup -and $lookup -is [System.Collections.IDictionary]) {
                $childEntity = $lookup
            } else {
                # As a last resort, try ScenarioLibrary resolution (supports nested sceny).
                if ($Context.ContainsKey('ScenarioLibrary') -and $Context['ScenarioLibrary'] -is [System.Collections.IDictionary]) {
                    $lib = $Context['ScenarioLibrary']
                    if ($lib.Contains($child) -and $null -ne $lib[$child]) {
                        $resolved = Convert-JaxScenarioItemToRunEntity -Key $child -Value $lib[$child] -ScenarioName "Library:$child" -ProvenancePath "ScenarioLibrary" -Context $Context @commonParams
                        if ($resolved -is [System.Collections.IDictionary]) {
                            $childEntity = $resolved
                        } elseif ($resolved -is [System.Collections.IEnumerable] -and $resolved -isnot [string]) {
                            foreach ($r in @($resolved)) {
                                if ($r -is [System.Collections.IDictionary]) {
                                    $result += Expand-JaxScenarioEntity -Entity $r -Context $Context -InheritedArgs $effectiveArgs -Depth ($Depth - 1) @commonParams
                                }
                            }
                            continue
                        }
                    }
                }
            }
        }

        if ($null -eq $childEntity -or $childEntity -isnot [System.Collections.IDictionary]) {
            continue
        }

        $result += Expand-JaxScenarioEntity -Entity $childEntity -Context $Context -InheritedArgs $effectiveArgs -Depth ($Depth - 1) @commonParams
    }

    return @($result)
}
