function Test-IsOrderedDictionaryOrHashtable {
    param (
        [Parameter()]
        $value
    )

    if ($null -eq $value) {
        return $false
    }

    return ($value -is [hashtable]) -or (Test-IsOrderedDictionary $value)
}
