function Resolve-PlaceholderOrThrow {
    [cmdletbinding()]
    param (
        [switch] $treatMissingValueAsFalse,
        [switch] $ignoreMissingPlaceholders,
        [string[]] $sourcePaths,
        [string] $varName,
        [string] $path,
        [switch] $dontThrow
    )
    # Write-Debug "Starting Resolve-PlaceholderOrThrow with params: varName='$varName', path='$path', dontThrow='$dontThrow'"
    # if no variable found in the subtree expansion
    if ($ignoreMissingPlaceholders -eq $true) {
        return  ""
    } else {
        if ($treatMissingValueAsFalse -eq $true) {
            return  $false
        } else {
            if ($dontThrow -ne $true) {
                Throw-PlaceholderNotFound -variable $varName -path $path -sourcePaths $sourcePaths
            } else {
                return "INVALID_PLACEHOLDER_$varName"
            }
        }
    }
}