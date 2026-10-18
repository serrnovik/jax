function Test-JaxTaskPatternMatch {
    <#
    .SYNOPSIS
    Case-insensitive substring match; * and ? act as wildcards anywhere in the pattern.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $true)]
        [string] $Pattern
    )

    # [ ] are literal: task names never use them and -like would treat them as a set.
    $escaped = $Pattern.Trim().Replace('[', '`[').Replace(']', '`]')
    return $Name -like "*$escaped*"
}
