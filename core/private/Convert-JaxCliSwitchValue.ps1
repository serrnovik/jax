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

    # `-flag:$false` from a POSIX shell arrives as the literal text '$false'.
    $text = $Value.ToString().Trim().TrimStart('$').ToLowerInvariant()
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
