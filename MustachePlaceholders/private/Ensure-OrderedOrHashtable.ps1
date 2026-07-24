function Ensure-OrderedOrHashtable {
    [CmdletBinding()]
    param (
        $inputObject,
        $message
    )

    if ($null -eq $inputObject) {
        return
    }

    if (-not (Test-IsOrderedDictionaryOrHashtable $inputObject)) {
        throw "Object must be hashtable or ordered. $message Got: $($inputObject.GetType())"
    }
}
