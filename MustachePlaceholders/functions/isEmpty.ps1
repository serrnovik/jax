
Register-PlaceholderFunction "isEmpty" {
    param($thisValue)
    return (-not ( & $global:PlaceholderFunctions['isSet'] $thisValue ))
}
