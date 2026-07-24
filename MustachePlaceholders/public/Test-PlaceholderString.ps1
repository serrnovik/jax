function Test-PlaceholderString {
    [cmdletbinding()]
    param (
        [string] $str,
        [string] $regex = $PLACEHOLDER_REGEX
    )
    return $str -match $regex
}