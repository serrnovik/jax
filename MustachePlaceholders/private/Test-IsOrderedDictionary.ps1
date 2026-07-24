function Test-IsOrderedDictionary {
    param (
        $obj
    )

    return $obj -is [System.Collections.Specialized.OrderedDictionary]
}
