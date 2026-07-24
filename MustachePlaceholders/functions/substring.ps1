Register-PlaceholderFunction "substring" {
    param(
        [string] $thisValue,
        $from,
        $to
    )

    if ($from -is [int] -and $to -is [int]) {
        return $thisValue.Substring($from, $to)
    } elseif ($from -is [int]) {
        return $thisValue.Substring($from)
    } else {
        throw "Error calling placeholder function 'substring': arguments are expected to be one or two integers (from, to)"
    }
}
