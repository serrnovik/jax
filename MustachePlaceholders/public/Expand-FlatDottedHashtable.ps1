function Expand-FlatDottedHashtable {
    [cmdletbinding()]
    param (
        [hashtable] $flatHT
    )
    $flatHtKeys = $flatHT.keys

    $resultHT = @{}
    foreach ($thisKey in  $flatHtKeys) {

        $thisValue = $flatHT[$thisKey]
        $splitted = $thisKey.Split('.')
        $currentNode = $resultHT
        $counter = 0
        foreach ($currentPart in $splitted) {
            if ([string]::IsNullOrWhiteSpace($currentPart)) {
                throw "Variable '$thisKey' could not be parsed"
            }
            $counter = $counter + 1


            if ($currentNode.Contains($currentPart)) {
                $currentlyHeldValue = $currentNode[ $currentPart ]
                if ($currentlyHeldValue -is [string]) {
                    # competition: most specific value wins
                    $newHT = @{}
                    $currentNode[ $currentPart] = $newHT
                    $currentNode = $newHT
                } else {
                    $currentNode = $currentNode[ $currentPart ]
                }

            } else {
                if ($counter -eq $splitted.Length) {
                    $currentNode[ $currentPart ] = $thisValue
                    break
                }
                $newHT = @{}
                $currentNode[ $currentPart] = $newHT
                $currentNode = $newHT
            }

        }

    }
    return $resultHT
}
