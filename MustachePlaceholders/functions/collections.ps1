Register-PlaceholderFunction "first" {
    param($thisValue)
    if ($null -eq $thisValue) {
        return $null
    }
    if ($thisValue -is [string]) {
        return $thisValue
    }
    $itemIsDictionary = $thisValue -is [System.Collections.IDictionary]
    $itemIsEnumerable = $thisValue -is [System.Collections.IEnumerable]
    if ($itemIsEnumerable -and -not $itemIsDictionary) {
        foreach ($item in $thisValue) {
            return $item
        }
        return $null
    }
    return $thisValue
}

Register-PlaceholderFunction "length" {
    param($thisValue)
    if ($thisValue -is [string]) { return $thisValue.Length }
    if ($thisValue -is [System.Collections.ICollection]) { return $thisValue.Count }
    if ($thisValue -is [System.Collections.IEnumerable]) { $c = 0; foreach ($i in $thisValue) { $c++ } ; return $c }
    return 0
}
Register-PlaceholderFunction "keys" {
    param($thisValue)
    if ($thisValue -is [System.Collections.IDictionary]) { return @($thisValue.Keys) }
    return @()
}

Register-PlaceholderFunction "mergeLists" {
    param($thisValue, $first)

    $extraArgs = @()
    $hasFirstArgument = $PSBoundParameters.ContainsKey('first')
    if ($hasFirstArgument) {
        $extraArgs += ,$first
    }
    if ($args) {
        $extraArgs += $args
    }

    $hasExtraArgs = $extraArgs.Count -gt 0
    $nonStringExtraArgs = @($extraArgs | Where-Object { $_ -isnot [string] })
    $extraArgsAreStrings = $hasExtraArgs -and ($nonStringExtraArgs.Count -eq 0)
    $shouldResolveKeys = ($thisValue -is [System.Collections.IDictionary]) -and $extraArgsAreStrings

    $listsToMerge = @()
    if ($shouldResolveKeys) {
        foreach ($key in $extraArgs) {
            if ([string]::IsNullOrWhiteSpace($key)) { continue }
            if ($thisValue.Contains($key)) {
                $listsToMerge += ,$thisValue[$key]
            }
        }
    } else {
        if ($null -ne $thisValue) {
            $listsToMerge += ,$thisValue
        }
        if ($hasExtraArgs) {
            $listsToMerge += $extraArgs
        }
    }

    $result = @()
    $seen = New-Object 'System.Collections.Generic.HashSet[object]'

    foreach ($listItem in $listsToMerge) {
        if ($null -eq $listItem) { continue }

        $itemIsEnumerable = $listItem -is [System.Collections.IEnumerable]
        $itemIsString = $listItem -is [string]
        $itemIsDictionary = $listItem -is [System.Collections.IDictionary]
        $shouldEnumerateItem = $itemIsEnumerable -and (-not $itemIsString) -and (-not $itemIsDictionary)

        if ($shouldEnumerateItem) {
            foreach ($value in $listItem) {
                if ($null -eq $value) { continue }
                if ($seen.Add($value)) { $result += $value }
            }
            continue
        }

        if ($seen.Add($listItem)) { $result += $listItem }
    }

    return $result
}
