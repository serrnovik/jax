Register-PlaceholderFunction "whenEq" {
    param(
        $thisValue,
        $expected,
        $thenValue,
        $elseValue
    )
    if ($thisValue -eq $expected) { return $thenValue }
    return $elseValue
}
