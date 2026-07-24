function Convert-JaxCliSwitchValue {
    [CmdletBinding()]
    param (
        $Value
    )

    if ($null -eq $Value) {
        return $true
    }

    if ($Value -is [bool]) {
        return $Value
    }

    $text = $Value.ToString().Trim().ToLowerInvariant()
    switch ($text) {
        '1' { return $true }
        'true' { return $true }
        'yes' { return $true }
        'y' { return $true }
        'on' { return $true }
        '0' { return $false }
        'false' { return $false }
        'no' { return $false }
        'n' { return $false }
        'off' { return $false }
        default { return $true }
    }
}
