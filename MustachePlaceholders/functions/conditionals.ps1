Register-PlaceholderFunction "ifElse" {
    param($thisValue, $thenValue, $elseValue)
    if ([bool]$thisValue) { return $thenValue }
    return $elseValue
}
