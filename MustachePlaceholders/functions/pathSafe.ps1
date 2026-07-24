Register-PlaceholderFunction "pathSafe" {
    param(
        [string] $thisValue
    )
    # Normalize to OS-native separator

    # shall we convert to windows native pathes or linux style just fine?
    # if ($isWindows) {
    #     # Convert forward slashes to backslashes
    #     return $thisValue -replace '/', '\\'
    # }
    # else {
    # Convert backslashes to forward slashes
    return $thisValue -replace '\\', '/'
    # }
}
