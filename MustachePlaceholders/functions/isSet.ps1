Register-PlaceholderFunction "isSet" {
    param($thisValue)
    if ($null -eq $thisValue) { return $false }
    if ($thisValue -is [string]) { return -not [string]::IsNullOrWhiteSpace($thisValue) }
    if ($thisValue -is [System.Collections.ICollection]) { return ($thisValue.Count -gt 0) }
    return $true
}