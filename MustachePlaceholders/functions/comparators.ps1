Register-PlaceholderFunction "eq" { param($thisValue, $other) return ($thisValue -eq $other) }
Register-PlaceholderFunction "ne" { param($thisValue, $other) return ($thisValue -ne $other) }
Register-PlaceholderFunction "gt" { param($thisValue, $other) return ($thisValue -gt $other) }
Register-PlaceholderFunction "lt" { param($thisValue, $other) return ($thisValue -lt $other) }
Register-PlaceholderFunction "ge" { param($thisValue, $other) return ($thisValue -ge $other) }
Register-PlaceholderFunction "le" { param($thisValue, $other) return ($thisValue -le $other) }
