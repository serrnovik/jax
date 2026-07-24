Register-PlaceholderFunction "trim" {
    param($thisValue)
    if ($thisValue -is [string]) { return $thisValue.Trim() }
    return $thisValue
}
Register-PlaceholderFunction "split" {
    param($thisValue, [string]$sep)
    if ($thisValue -is [string]) { return $thisValue.Split($sep) }
    return @($thisValue)
}
Register-PlaceholderFunction "join" {
    param($thisValue, [string]$sep)
    if ($thisValue -is [System.Collections.IEnumerable]) { return -join ($thisValue -join $sep) }
    return [string]$thisValue
}
Register-PlaceholderFunction "startsWith" {
    param($thisValue, [string]$prefix)
    if ($thisValue -is [string]) { return $thisValue.StartsWith($prefix) }
    return $false
}
Register-PlaceholderFunction "endsWith" {
    param($thisValue, [string]$suffix)
    if ($thisValue -is [string]) { return $thisValue.EndsWith($suffix) }
    return $false
}
Register-PlaceholderFunction "contains" {
    param($thisValue, $needle)
    if ($thisValue -is [string]) { return ($thisValue.Contains([string]$needle)) }
    if ($thisValue -is [System.Collections.IDictionary]) { return $thisValue.Contains($needle) }
    if ($thisValue -is [System.Collections.IEnumerable]) {
        foreach ($i in $thisValue) { if ($i -eq $needle) { return $true } }
        return $false
    }
    return $false
}
