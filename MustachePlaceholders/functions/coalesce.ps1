Register-PlaceholderFunction "coalesce" {
    param($thisValue, $fallback)
    if ($null -eq $thisValue) { return $fallback }
    if ($thisValue -is [string]) { if ([string]::IsNullOrWhiteSpace($thisValue)) { return $fallback } }
    if ($thisValue -is [System.Collections.ICollection]) { if ($thisValue.Count -eq 0) { return $fallback } }
    return $thisValue
}
