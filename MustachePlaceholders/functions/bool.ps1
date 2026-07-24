Register-PlaceholderFunction "and" { param($thisValue, $other) if ($thisValue) { return [bool]$other } return $false }
Register-PlaceholderFunction "or"  { param($thisValue, $other) if ($thisValue) { return $true } return [bool]$other }
Register-PlaceholderFunction "not" { param($thisValue) return (-not [bool]$thisValue) }
