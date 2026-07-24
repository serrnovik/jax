Register-PlaceholderFunction "default" {
    param(
        $thisValue,
        $defaultValue
    )

    # If the provided default is an empty collection, coerce to empty string to avoid emitting '[]'
    if ($defaultValue -is [System.Collections.ICollection] -and $defaultValue.Count -eq 0) {
        $defaultValue = ""
    }

    if ($null -eq $thisValue) { return $defaultValue }
    # Treat internal sentinel as missing value
    if ($thisValue -is [string] -and -not [string]::IsNullOrWhiteSpace($thisValue)) {
        try {
            if ($thisValue -eq $PATH_NOT_FOUND_IN_HASHTABLE) { return $defaultValue }
        } catch { }
    }
    if ($thisValue -is [string]) {
        if ([string]::IsNullOrWhiteSpace($thisValue)) { return $defaultValue }
        return $thisValue
    }
    if ($thisValue -is [System.Collections.ICollection]) {
        if ($thisValue.Count -eq 0) { return $defaultValue }
        return $thisValue
    }
    return $thisValue
}
