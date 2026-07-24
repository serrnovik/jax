Register-PlaceholderFunction "toLower" {
    param(
        [string] $thisValue
    )
    return $thisValue.ToLower()
}
