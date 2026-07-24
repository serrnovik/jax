function Convert-PlaceholderMatch {
    [cmdletbinding()]
    param (
        [string] $str,
        [string] $before,
        [string] $after,
        [string] $regex = $PLACEHOLDER_REGEX
    )

    $str -replace $regex, "$($before)`$1$($after)"
}