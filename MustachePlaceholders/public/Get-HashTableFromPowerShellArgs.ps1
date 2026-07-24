function Get-HashTableFromPowerShellArgs {
    [cmdletbinding()]
    param (
        $varsStr
    )

    $varsHashTable = @{}
    for ($i = 0; $i -lt $varsStr.count; $i += 1) {
        if ($varsStr[$i].StartsWith('-')) {
            # we only support named parameters
            if ($i -lt ($varsStr.Count - 1) -and ($varsStr[$i + 1] -is [bool])) {
                $switchName = ($varsStr[$i] -replace '^-+').TrimEnd(":")
                $switchValue = $varsStr[$i + 1]



                $i = $i + 1

                $varsHashTable[$switchName] = $switchValue
            } elseif ($i -eq ($varsStr.Count - 1) -or ($varsStr[$i + 1] -is [string] -and $varsStr[$i + 1].StartsWith('-'))) {
                # this is switch if: a) it's the last one b) next one is named parameter
                $switchStr = ($varsStr[$i] -replace '^-+')
                $switchValue = $true
                $switchName = $switchStr

                $switchSplit = $switchStr.Split(":")
                if ($switchSplit.Length -gt 2) {
                    throw "Wrong switch format ('$switchStr')"
                }

                if ($switchSplit.Length -eq 2) {
                    $switchName = $switchSplit[0]
                    $switchValue = $switchSplit[1]

                    if ($switchValue.ToLower() -eq "true") {
                        $switchValue = $true
                    } elseif ($switchValue.ToLower() -eq "false") {
                        $switchValue = $false
                    } else {
                        throw "Wrong switch format ('$switchStr')"
                    }
                }

                $varsHashTable[$switchName] = $switchValue
            } else {

                if ($varsStr[$i].EndsWith(":")) {
                    throw "Switch '$($varsStr[$i].TrimEnd(":"))' contained a non-boolean value '$($varsStr[$i + 1])'"
                }


                $varsHashTable[($varsStr[$i] -replace '^-+')] = $varsStr[$i + 1]
                $i = $i + 1
            }
        } else {
            throw "Don't support positional parameters for bob ('$($varsStr[$i])'): use only named ones"
        }
    }

    return $varsHashTable
}