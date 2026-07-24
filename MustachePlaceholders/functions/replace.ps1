Register-PlaceholderFunction "replace" {
    param(
        [string] $thisValue,
        $what,
        $withWhat = ""
    )
    if ($withWhat -eq "" -and $what -match "^(.*),(.*)$") {
        $what = $matches[1]
        $withWhat = $matches[2]
    }
    if ($what -is [string] -and $withWhat -is [string]) {
        return $thisValue.Replace($what, $withWhat)
    } else {
        throw "Function 'replace' parameters must be two strings"
    }
}
