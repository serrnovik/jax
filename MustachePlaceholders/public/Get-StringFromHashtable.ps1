function Get-StringFromHashtable {
    [cmdletbinding()]
    param (
        [hashtable] $ht
    )
    $str = "@{"
    $isFirst = $true
    $ht.getEnumerator() | ForEach-Object {
        if ($isFirst) {
            $isFirst = $false
        } else {
            $str = "$str;"
        }
        if ($_.value -is [hashtable]) {
            $str = "$str""$prefix$($_.key)""=$(Get-StringFromHashtable $_.value)"
        } else {
            $safeValue = $_.value -replace '"', '`"'  # escape if the value contains quotes ( this is to avoid issues with docker for params like mongo scripts where we have quotes in the value)
            $str = "$str""$($_.key)""=""$($safeValue)"""
        }
    }
    $str = "$str}"
    # if($isNotFirst)
    # {
    #     $str = "$str;"
    # }
    return $str
}
