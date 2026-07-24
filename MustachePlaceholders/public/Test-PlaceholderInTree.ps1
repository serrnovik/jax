function Test-PlaceholderInTree {
    [cmdletbinding()]
    param (
        $node,
        [string] $paramName
    )

    $paramNameSplit = $paramName.Split(".")
    $last = $paramNameSplit.Length -eq 1
    $rest = $paramNameSplit[1..$paramNameSplit.Length] -join "."
    $currentParamPart = $paramNameSplit[0]

    $currentParamPart = $currentParamPart.TrimEnd("?")

    if (Test-ValuePrimitive $node) {
        # primitive value: usually string or int or bool
        # primitive value
        if ($null -eq $node) {
            return $null
        }
        $value = $node.ToString()

        if ($value -eq $currentParamPart) {
            # if current node is a primitive
            if ($last) {
                return "yes"
            } else {
                return $null
            }
        }
        return $null
    } elseif ($node -is [System.Collections.IDictionary]) {
        foreach ($key in $node.Keys) {
            $value = $node[$key]

            if ($currentParamPart -eq $key) {
                if (Test-ValuePrimitive $value) {
                    if ($last) {
                        return $value
                    } else {
                        $recResult = Test-PlaceholderInTree $value $rest

                        if ($null -ne $recResult) {
                            return $recResult
                        }
                    }
                } else {
                    if ($last) {
                        return "yes"
                    } else {
                        $recResult = Test-PlaceholderInTree $value $rest
                        if ($null -ne $recResult) {
                            return $recResult
                        }
                        continue
                    }
                }
            }
        }

        return $null
    } elseif ($node -is [System.Collections.IEnumerable]) {
        foreach ($value in $node) {
            if (Test-ValuePrimitive $value) {
                if ($last -and $value -eq $currentParamPart) {
                    return "yes"
                }
            } else {
                $recResult = Test-PlaceholderInTree $value $paramName
                if ($null -ne $recResult) {
                    return $recResult
                }
                continue
                # Write-TeamCityYaml $value $prefix
            }
        }
        return $null
    } else {
        throw "Unknown node type during getting the placeholders: $(if ($null -ne $node) { $node.GetType() } else {"null"})"
    }

    return $null
}
