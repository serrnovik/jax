Register-PlaceholderFunction "toCanonicalDotnet" {
    param(
        [string] $thisValue
    )

    # Short .NET target framework names to their dotted form:
    # net80 -> net8.0, net10 / net100 -> net10.0, netcoreapp31 -> netcoreapp3.1.
    # .NET Framework names (net472, net48) and dotted names pass through unchanged.
    $value = $thisValue.Trim()
    if ($value -match '^net(1[0-9])0?$') {
        return "net$($Matches[1]).0"
    }
    if ($value -match '^net([5-9])([0-9])$') {
        return "net$($Matches[1]).$($Matches[2])"
    }
    if ($value -match '^netcoreapp([1-3])([0-9])$') {
        return "netcoreapp$($Matches[1]).$($Matches[2])"
    }
    return $thisValue
}
