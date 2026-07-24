function Test-PlaceholderInContext {
    param(
        [System.Collections.IDictionary] $override,
        [System.Collections.IDictionary] $ht,
        [string] $paramName
    )

    if ($override) {
        if ($override.Contains($paramName)) {
            return $override[$paramName]
        } else {
            $htResult = Test-PlaceholderInTree $override $paramName
            if ($null -ne $htResult) {
                return $htResult
            }
        }
    }

    if ($ht) {
        $htResult = Test-PlaceholderInTree $ht $paramName
        if ($null -ne $htResult) {
            return $htResult
        }
    }

    return $null
}
