Register-PlaceholderFunction "toUpper" {
    param(
        [string] $thisValue
    )
    return $thisValue.ToUpper()
}
