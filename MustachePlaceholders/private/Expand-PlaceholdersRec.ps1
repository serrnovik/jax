function Expand-PlaceholdersRec {
    [cmdletbinding()]
    param (
        $node,
        [System.Collections.IDictionary] $ht,
        [System.Collections.IDictionary] $override,
        [string[]] $sourcePaths,
        [switch] $treatMissingValueAsFalse,
        [switch] $ignoreMissingPlaceholders,
        [switch] $dontThrow,
        [string] $path,
        [int] $maxDepth = 10
    )
    # Write-Debug "Expanding placeholders in '$path' with max depth of $maxDepth. Node type = $($node.GetType())"

    $commonPSBoundParameters = Get-CommonParameters -BoundParameters $PSBoundParameters
    if ($maxDepth -le 0) {
        # throw "Max depth of recursion reached. Will not expand placeholders in '$path'"
        return $node
    }

    $commonSettings = @{
        treatMissingValueAsFalse = $treatMissingValueAsFalse
        ignoreMissingPlaceholders   = $ignoreMissingPlaceholders
        dontThrow                = $dontThrow
    }

    $maxDepth = $maxDepth - 1

    if ($node -is [string]) {
        # in string case there might be substitutions
        $stringValue = $node.ToString()
        $depthCounter = 0
        $RECURSION_MAX_DEPTH = 50
        $regex = [regex]$PLACEHOLDER_REGEX
        $regexOnly = [regex]$PLACEHOLDER_ONLY_REGEX

        # Handle escaped substitutions ~!{{ ... }} by protecting them from expansion
        $escapedSubstitutionsMap = @{}
        $escapedSubstitutionCounter = 0
        $escapedSubstitutionRegex = [regex]"~!\{\{[^\}]*\}\}"
        $escapedMatches = $escapedSubstitutionRegex.Matches($stringValue)

        foreach ($escapedMatch in $escapedMatches) {
            $placeholder = "__ESCAPED_SUB_${escapedSubstitutionCounter}__"
            $escapedSubstitutionsMap[$placeholder] = $escapedMatch.Value
            $stringValue = $stringValue.Replace($escapedMatch.Value, $placeholder)
            $escapedSubstitutionCounter++
        }

        do {
            $beforeSubstitution = $stringValue

            $patternToBlockYamlConversion = "~!" # like to avoid "`!2022-10-24" to be converted to dateTime
            # also used in Identify-ParamsFromBobFileForRunEntity.ps1
            #! if pattern change change there as well

            # Date escaping: only strip ~! at start if NOT followed by {{
            if (($stringValue -is [string]) -and $stringValue.StartsWith($patternToBlockYamlConversion) -and -not $stringValue.StartsWith("~!{{")) {
                #remove from start
                $stringValue = $stringValue.Substring($patternToBlockYamlConversion.Length)
            }

            $matchList = $regex.Matches($stringValue)
            $isPureSubstitution = $regexOnly.IsMatch($stringValue)
            $hasMultipleSubs = ($matchList.Count -gt 1)

            if ($isPureSubstitution -and -not $hasMultipleSubs) {
                # pure substitution case: "{{ some.var }}"
                $varName = $regexOnly.Match($stringValue).Groups[1].Value

                $varValue = Get-PathFromHashtable $ht $varName -override $override -dontThrow
                $varValueOrYes = Test-PlaceholderInContext $override $ht $varName # returns yes when non primitive or intermediate value
                # detect pipeline presence for pure substitution
                $mPure = $regex.Match($stringValue)
                if ($mPure.Success) {
                    $pipelineGroupPure = $mPure.Groups[$pipeLineGroupName]
                    if ($pipelineGroupPure.Success -and -not [string]::IsNullOrWhiteSpace($pipelineGroupPure.Value)) {
                        return (Expand-PlaceholderPipelineRec -value $varValue -pipeline $pipelineGroupPure.Value @commonPSBoundParameters)
                    }
                }

                if ($varValueOrYes -eq "yes" -and $varValue -is [System.Collections.IDictionary]) {
                    # (pipeline for pure substitution handled above)
                    # case where the substituted value is a hashtable
                    # Write-Debug "recursive call Expand-PlaceholdersRec, case where the substituted value is a hashtable"
                    return Expand-PlaceholdersRec $varValue $ht $override -sourcePaths $sourcePaths -path $path -maxDepth $maxDepth @commonSettings @commonPSBoundParameters  # it's a final substitution, return the expanded tree
                }

                if ($varValueOrYes -eq "yes" -and ($varValue -is [array] -or $varValue -is [System.Collections.IList])) {
                    # (pipeline for pure substitution handled above)
                    $result = @(
                        foreach ($item in $varValue) {
                            # Write-Debug "recursive call Expand-PlaceholdersRec, case where the substituted value is an array"
                            $expandedValue = Expand-PlaceholdersRec $item $ht $override -sourcePaths $sourcePaths -path $path -maxDepth $maxDepth @commonSettings @commonPSBoundParameters
                            $expandedValue # emit to array
                        }
                    )
                    # note: WE DO NOT YET handle(or tested) case if array is not a primitive result.
                    # note: merging arrays is not yet supported as well. You'd probably ended to add function to that
                    return $result
                }


                # Here we have some variable 'a.b.c...z' which was not found
                # Let's try finding such a tree node 'a' or 'a.b' until 'a.b...y' which will contain a pure substitution which in turn will be a hashtable
                if ($PATH_NOT_FOUND_IN_HASHTABLE -eq $varValue) {
                    $splitVarName = $varName.Split(".")

                    if ($splitVarName.Length -lt 2) {
                        # if it already was a simple variable, no subtree is possible
                        # Write-Debug "Recursive call Expand-PlaceholdersRec case1, with params: varName='$varName', path='$path', commonSettings=$($commonSettings |ConvertTo-Json -Depth 10)"
                        $stringValue = Resolve-PlaceholderOrThrow -varName $varName -path $path -sourcePaths $sourcePaths @commonSettings @commonPSBoundParameters
                    } else {
                        $currentNode = $ht

                        $variableHandledSomeSubtree = $false
                        # we descend until the (N-1)-th var name component (in case of `a.b.c...y.z` -> `a.b...y`)
                        # we look for the first tree node which contains some hashtable (when expanded)
                        for ($i = 0; $i -lt $splitVarName.Count - 1; $i++) {
                            $currentVarNameElement = $splitVarName[$i]
                            $nextElement = $currentNode.$currentVarNameElement

                            if ($nextElement -is [string] -and $regex.IsMatch($nextElement)) {
                                # is `a.b` a pure substitution ?
                                # Write-Debug "recursive call Expand-PlaceholdersRec, case where the substituted value is a string and it is a pure substitution"
                                $expandedValue = Expand-PlaceholdersRec $nextElement $ht $override -sourcePaths $sourcePaths -path "$($path).$($currentVarNameElement)" -maxDepth $maxDepth @commonSettings @commonPSBoundParameters

                                if ($expandedValue -is [System.Collections.IDictionary]) {
                                    # if the value is hashtable, there's still chance to find a variable
                                    $remainingVarName = $splitVarName[($i + 1)..($splitVarName.Count - 1)] -join '.' # the path to the variable in the found subtree
                                    $varValue = Get-PathFromHashtable $expandedValue $remainingVarName -override $override -dontThrow

                                    if ($PATH_NOT_FOUND_IN_HASHTABLE -eq $varValue) {
                                        $variableHandledSomeSubtree = $true
                                        # Write-Debug "Recursive call Expand-PlaceholdersRec case 2, with params: varName='$varName', path='$path', commonSettings=$($commonSettings | ConvertTo-Json -Depth 10)"
                                        $stringValue = Resolve-PlaceholderOrThrow -varName $varName -path $path -sourcePaths $sourcePaths @commonSettings @commonPSBoundParameters
                                    } elseif ($varValue -is [string]) {
                                        # if it's a string, it can be another substitution, so we leave it for next `do` cycle pass
                                        $variableHandledSomeSubtree = $true
                                        $stringValue = $varValue
                                    } else {
                                        # otherwise it's what we looked for
                                        return $varValue
                                    }
                                }

                                break # the resulted substitution is not a hashtable and we drop it
                            }

                            $currentNode = $nextElement
                        }

                        if (!$variableHandledSomeSubtree) {
                            # Write-Debug "Recursive call Expand-PlaceholdersRec case 3 -> with params: varName='$varName', path='$path', commonSettings=$($commonSettings | ConvertTo-Json -Depth 10)"
                            $stringValue = Resolve-PlaceholderOrThrow -varName $varName -path $path -sourcePaths $sourcePaths @commonSettings @commonPSBoundParameters
                            # Write-Debug "relutive value for case 3: $stringValue"
                        }
                    }

                } else {
                    # if there was some value
                    $pipelineGroups = $matchList.Groups | Where-Object { $_.Name -eq $pipeLineGroupName }
                    $hasPipeline = (@($pipelineGroups).Count -eq 1) -and ($null -ne $pipelineGroups[0]) -and (-not [string]::IsNullOrWhiteSpace($pipelineGroups[0].Value))

                    if ($hasPipeline) {
                        # Apply pipeline regardless of the underlying type (null, bool, number, string, etc.)
                        $pipelineGroup = $pipelineGroups[0]
                        return (Expand-PlaceholderPipelineRec -value $varValue -pipeline $pipelineGroup.Value @commonPSBoundParameters)
                    }

                    if ($varValueOrYes -is [string]) {
                        # no pipeline; continue resolving nested substitutions if the value is string
                        $stringValue = $varValue
                    } else {
                        # primitive value (including $null) without pipeline: return as-is
                        return $varValueOrYes
                    }
                }
            } else {
                # string interpolation case: e.g. `This is {{ params.name? | toLower() }}`
                foreach ($match in $matchList) {
                    $expr = $match.Groups[0].Value
                    # Write-Debug "recursive call Expand-PlaceholdersRec, case where the substituted value is a string and it is not a pure substitution"
                    $varValue = Expand-PlaceholdersRec $expr $ht $override -sourcePaths $sourcePaths -path $path -maxDepth $maxDepth @commonSettings @commonPSBoundParameters

                    if ($null -eq $varValue) {
                        $varValue = ""
                    }

                    $varValue = $varValue.ToString() # we never leave the string space with string interpolation

                    $stringValue = $stringValue.Replace($match.Value, $varValue)
                }
            }

            $depthCounter += 1
        } while ($beforeSubstitution -ne $stringValue -and $depthCounter -le $RECURSION_MAX_DEPTH)

        if ($depthCounter -ge $RECURSION_MAX_DEPTH) {
            throw "Recursion in placeholders declaration in one of the placeholders."
        }

        # Restore escaped substitutions from placeholders
        foreach ($placeholder in $escapedSubstitutionsMap.Keys) {
            $stringValue = $stringValue.Replace($placeholder, $escapedSubstitutionsMap[$placeholder])
        }

        return $stringValue
    } elseif (Test-ValuePrimitive $node) {
        return $node
    } elseif (Test-IsOrderedDictionary $node) { # [System.Collections.Specialized.OrderedDictionary] === [ordered] ordered dictionary
        # Preserve ordering (important for YAML maps like scenario steps).

        $res = [ordered]@{}

        foreach ($key in $node.Keys) {
            $childNode = $node[$key]
            if ($null -ne $childNode) { # case where ' "myProperty": null,'  is ok, nothing should be expanded
                # Write-Debug "Expanding key '$key' in path '$path'"

                # Write-Debug "recursive call Expand-PlaceholdersRec, case where the substituted value is an ordered dictionary"
                $expandedValue = Expand-PlaceholdersRec -node $childNode -ht $ht -override $override -sourcePaths $sourcePaths -path "$path.$key" -maxDepth $maxDepth @commonSettings @commonPSBoundParameters

                $res[$key] = $expandedValue
            } else {
                $res[$key] = $null
            }
        }

        return $res

    } elseif ($node -is [System.Collections.IDictionary] ) {
        # Preserve ordering (important for YAML maps like scenario steps).
        $res = [ordered]@{}
        $localKeys = $node.Keys | ForEach-Object { $_ }
        foreach ($key in $localKeys) {
            $value = $node[$key]
            # Write-Debug "recursive call Expand-PlaceholdersRec,  case where the substituted value is a hashtable"
            $expandResult = Expand-PlaceholdersRec $value $ht $override -sourcePaths $sourcePaths -path "$($path).$key" -maxDepth $maxDepth @commonSettings @commonPSBoundParameters
            $res[$key] = $expandResult
        }

        return $res

    } elseif ($node -is [System.Collections.IEnumerable]) {
        $res = @()

        foreach ($item in $node) {
            $res += @(, (Expand-PlaceholdersRec $item $ht $override -sourcePaths $sourcePaths -path "$($path).$i" -maxDepth $maxDepth @commonSettings @commonPSBoundParameters))
        }

        if ($res.Length -eq 1) {
            $res = @(, $res)
        }
        return $res
    } else {
        throw "Unsupported value '$node' (type: $($node.GetType()))"
    }

    return $res
}
