function Get-PathFromHashtable {
    [cmdletbinding()]
    param (
        [System.Collections.IDictionary] $ht,
        [string] $path,
        [System.Collections.IDictionary] $override = @{},
        $defaultValue = $PATH_NOT_FOUND_IN_HASHTABLE,
        [switch] $dontThrow
    )
    # Write-Host "Get-PathFromHashtable: path=$path, override=$($override | ConvertTo-Json -Depth 99), defaultValue=$defaultValue, dontThrow=$dontThrow" -ForegroundColor DarkGray
    if ($null -eq $ht) {
        throw "Hashtable is null: can't get value by path"
    }

    if (!$path) {
        return $ht
    }

    if ($override -and $override.Count -gt 0) {
        if ($override.Contains($path)) {
            # getting by flat dotted path
            return $override[$path]
        } else {
            # getting by structure (probe override non-throwing, fallback to main if not found)
            $value = Get-PathFromHashtable $override $path -dontThrow:$true -defaultValue $PATH_NOT_FOUND_IN_HASHTABLE

            if ($value -ne $PATH_NOT_FOUND_IN_HASHTABLE) {
                # if found the value in override
                return $value
            }
        }
    }

    $split = $path.Split(".")
    $current = $ht
    $isParentConditional = $false
    for ($i = 0; $i -lt $split.Length; $i++) {
        $currentPathElement = $split[$i]
        $isConditional = $currentPathElement.EndsWith("?")
        $currentPathElement = $currentPathElement.TrimEnd("?")

        if ($current -eq $null) {
            if (!$isParentConditional) {
                if ($dontThrow) {
                    return $defaultValue
                } else {
                    throw "Path '$path' is not found in the hashtable: access to null or non-existing value"
                }
            }
        } elseif ($current -is [array] -and ($null -ne $current.$currentPathElement)) {
            #array acces
            $current = $current.$currentPathElement
        } elseif ($current -is [System.Collections.IDictionary]) {
            # dictionary access
            if ($current.Contains($currentPathElement)) {
                $current = $current[$currentPathElement]
            } else {
                if ($isConditional) {
                    $current = $null
                } else {
                    if ($dontThrow) {
                        return $defaultValue
                    } else {
                        throw "Path '$path' is not found in the hashtable."
                    }
                }
            }
        } else {
            # not hashtable and not array
            if ($dontThrow) {
                return $defaultValue
            } else {
                throw "Path '$path' is not found in the hashtable: accessing something other than hahstable or array."
            }
        }

        $isParentConditional = $isConditional
    }

    return $current
}
