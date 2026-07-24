function Test-ValuePrimitive {
    param(
        $value
    )

    return $value -is [string] -or -not ($value -is [System.Collections.IEnumerable])
}