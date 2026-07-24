function Test-JaxDictionaryHasKey {
    [CmdletBinding()]
    param (
        [System.Collections.IDictionary] $Dictionary,
        [string] $Key
    )

    if ($null -eq $Dictionary -or [string]::IsNullOrWhiteSpace($Key)) {
        return $false
    }

    if ($Dictionary.PSObject.Methods.Match('ContainsKey').Count -gt 0) {
        return [bool]$Dictionary.ContainsKey($Key)
    }
    if ($Dictionary.PSObject.Methods.Match('Contains').Count -gt 0) {
        return [bool]$Dictionary.Contains($Key)
    }

    return ($Dictionary.Keys -contains $Key)
}
