function Resolve-JaxRunPlan {
    [CmdletBinding()]
    param (
        [object[]] $BuildEntities,
        [object[]] $ScenarioEntities,
        [object[]] $IndividualEntities,
        [switch] $NoBuild,
        [switch] $BuildChainOnly,
        [AllowNull()]
        $Only,
        [string] $From,
        [string] $To,
        [hashtable] $Context
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if ($NoBuild -and $BuildChainOnly) {
        throw "Cannot combine -NoBuild with -BuildChainOnly."
    }

    $plan = @()
    if (-not $NoBuild -and $null -ne $BuildEntities) {
        $plan += @($BuildEntities)
    }
    if (-not $BuildChainOnly -and $null -ne $ScenarioEntities) {
        $plan += @($ScenarioEntities)
    }

    $onlySelectors = @(Get-JaxOnlySelectors -Only $Only)
    $hasOnlySelector = $onlySelectors.Count -gt 0
    $hasMultipleOnlySelectors = $onlySelectors.Count -gt 1
    $singleOnlySelector = if ($onlySelectors.Count -eq 1) { $onlySelectors[0] } else { $null }
    $hasSliceRequest = -not [string]::IsNullOrWhiteSpace($From) -or -not [string]::IsNullOrWhiteSpace($To)

    function Resolve-OnlySelectorEntities {
        param(
            [Parameter(Mandatory = $true)]
            [string] $Selector,
            [switch] $ApplyLibrarySlice
        )

        $selectorSelected = @(Select-JaxRunEntities -Entities $plan -Only $Selector)

        if ($null -ne $IndividualEntities) {
            $individualSelected = @(Select-JaxRunEntities -Entities $IndividualEntities -Only $Selector)
            if ($individualSelected.Count -gt 0) {
                $selectorSelected = Merge-JaxRunEntityList -Base $selectorSelected -Add $individualSelected
            }
        }

        # Library fallback: if a selector is not in the active plan/discovered entities,
        # resolve it from ScenarioLibrary so ad-hoc lists can include library items too.
        if (($null -eq $selectorSelected -or $selectorSelected.Count -eq 0) -and $null -ne $Context -and $Context.ContainsKey('ScenarioLibrary') -and $Context['ScenarioLibrary'] -is [System.Collections.IDictionary]) {
            $library = $Context['ScenarioLibrary']
            $normalizedSelector = Convert-JaxRunEntityName -Name $Selector @commonParams
            $libKey = $null
            foreach ($k in $library.Keys) {
                $normalizedLibraryKey = Convert-JaxRunEntityName -Name $k @commonParams
                if ($normalizedLibraryKey -eq $normalizedSelector) {
                    $libKey = $k
                    break
                }
            }

            if ($null -ne $libKey) {
                Write-Debug "Resolve-JaxRunPlan: Found '$Selector' in ScenarioLibrary. Expanding..."
                $libValue = $library[$libKey]
                $libEntities = @()

                if ($libValue -is [System.Collections.IDictionary]) {
                    $libEntities += ,(Convert-JaxScenarioItemToRunEntity -Key $libKey -Value $libValue -ScenarioName "Library:$Selector" -ProvenancePath 'Library' -Context $Context)
                } elseif ($libValue -is [System.Collections.IEnumerable] -and $libValue -isnot [string]) {
                    $index = 0
                    foreach ($item in $libValue) {
                        $libEntities += ,(Convert-JaxScenarioItemToRunEntity -Key "${libKey}_$index" -Value $item -ScenarioName "Library:$Selector" -ProvenancePath 'Library' -Context $Context)
                        $index++
                    }
                } else {
                    $libEntities += ,(Convert-JaxScenarioItemToRunEntity -Key $libKey -Value $libValue -ScenarioName "Library:$Selector" -ProvenancePath 'Library' -Context $Context)
                }

                if ($ApplyLibrarySlice -and $hasSliceRequest -and $libEntities.Count -gt 0) {
                    $libraryScenario = [ordered]@{
                        Key      = $Selector
                        Runner   = 'scenario'
                        Entities = $libEntities
                    }
                    $slicedLibraryScenario = Get-SlicedScenarioEntity -Candidate $libraryScenario
                    if ($null -ne $slicedLibraryScenario -and $slicedLibraryScenario.Contains('Entities')) {
                        $libEntities = @($slicedLibraryScenario['Entities'])
                    } else {
                        $libEntities = @()
                    }
                }

                if ($libEntities.Count -gt 0) {
                    $selectorSelected = Merge-JaxRunEntityList -Base $selectorSelected -Add $libEntities
                }
            }
        }

        return @($selectorSelected)
    }

    function Get-SlicedScenarioEntity {
        param(
            [Parameter(Mandatory = $true)]
            $Candidate
        )

            $candidateDict = $null
            if ($Candidate -is [System.Collections.IDictionary]) {
                $candidateDict = $Candidate
            } elseif ($null -ne $Candidate) {
                $props = $Candidate.PSObject.Properties
                if ($props -and $props.Count -gt 0) {
                    $candidateDict = [ordered]@{}
                    foreach ($p in $props) {
                        $candidateDict[$p.Name] = $p.Value
                    }
                }
            }
            if ($candidateDict -isnot [System.Collections.IDictionary]) {
                return $null
            }
            if (-not $candidateDict.Contains('Runner')) {
                return $null
            }
            $runner = Resolve-JaxRunnerName -Name ([string]$candidateDict['Runner']) @commonParams
            if ($runner -ne 'scenario') {
                return $null
            }
            if (-not $candidateDict.Contains('Entities') -or $null -eq $candidateDict['Entities']) {
                return $null
            }

            $children = @($candidateDict['Entities'])
            if ($children.Count -eq 0) {
                return @()
            }

            $normalizedFrom = if ([string]::IsNullOrWhiteSpace($From)) { $null } else { Convert-JaxRunEntityName -Name $From @commonParams }
            $normalizedTo = if ([string]::IsNullOrWhiteSpace($To)) { $null } else { Convert-JaxRunEntityName -Name $To @commonParams }

            $fromIndex = 0
            if ($normalizedFrom) {
                $fromIndex = -1
                for ($i = 0; $i -lt $children.Count; $i++) {
                    if (Test-JaxRunEntityNameMatch -Entity $children[$i] -Name $From -MatchStartsWith) {
                        $fromIndex = $i
                        break
                    }
                }
                if ($fromIndex -lt 0) {
                    return @()
                }
            }

            $toIndex = $children.Count - 1
            if ($normalizedTo) {
                $toIndex = -1
                for ($i = $fromIndex; $i -lt $children.Count; $i++) {
                    if (Test-JaxRunEntityNameMatch -Entity $children[$i] -Name $To -MatchStartsWith) {
                        $toIndex = $i
                        break
                    }
                }
                if ($toIndex -lt 0) {
                    return @()
                }
            }

            if ($fromIndex -gt $toIndex) {
                return @()
            }

            $sliced = @()
            for ($i = $fromIndex; $i -le $toIndex; $i++) {
                $sliced += $children[$i]
            }

            $cloneScenario = [ordered]@{}
            foreach ($k in $candidateDict.Keys) {
                $cloneScenario[$k] = $candidateDict[$k]
            }
            $cloneScenario['Entities'] = $sliced
            return $cloneScenario
        }

    if ($hasMultipleOnlySelectors) {
        $virtualScenarioChildren = @()
        foreach ($selector in $onlySelectors) {
            $selectorEntities = @(Resolve-OnlySelectorEntities -Selector $selector)
            if ($selectorEntities.Count -eq 0) {
                throw "Could not resolve -only selector '$selector' while building an ad-hoc scenario."
            }

            $virtualScenarioChildren += $selectorEntities
        }

        $virtualScenario = [ordered]@{
            Key        = "ad-hoc:$($onlySelectors -join ',')"
            Runner     = 'scenario'
            Entities   = $virtualScenarioChildren
            Scenario   = 'ad-hoc'
            Provenance = 'cli'
            SourcePath = '-only'
        }

        if (-not $hasSliceRequest) {
            return @($virtualScenario)
        }

        $slicedVirtualScenario = Get-SlicedScenarioEntity -Candidate $virtualScenario
        if ($null -ne $slicedVirtualScenario) {
            return @($slicedVirtualScenario)
        }

        return @()
    }

    if ($hasOnlySelector) {
        $selected = @(Resolve-OnlySelectorEntities -Selector $singleOnlySelector -ApplyLibrarySlice)
    } else {
        $selected = @(Select-JaxRunEntities -Entities $plan -From $From -To $To)
    }

    if ($null -eq $selected) {
        return @()
    }

    if ($hasSliceRequest) {

        # Prefer slicing the entity selected by -Only (even when it came from IndividualEntities / library).
        if ($hasOnlySelector) {
            $onlyMatches = @()
            foreach ($item in @($selected)) {
                if (Test-JaxRunEntityNameMatch -Entity $item -Name $singleOnlySelector) {
                    $onlyMatches += $item
                }
            }
            if ($onlyMatches.Count -eq 1) {
                $slicedScenario = Get-SlicedScenarioEntity -Candidate $onlyMatches[0]
                if ($null -ne $slicedScenario) {
                    return @($slicedScenario)
                }
            }
        }

        # Fallback: if a single scenario was selected, slice within it.
        if ($selected.Count -eq 1) {
            $slicedScenario = Get-SlicedScenarioEntity -Candidate $selected[0]
            if ($null -ne $slicedScenario) {
                return @($slicedScenario)
            }
        }
    }

    return $selected
}
