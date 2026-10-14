properties {
    [bool]$boolFlag = $false
    # Braces below are the regression, not decoration: a comment mentioning
    # -properties @{ boolFlag = $true }, and a hashtable default, both used to
    # end the parsed block early and silently hide every property after them.
    $hashDefault = @{ nested = 'value' }
    [string]$afterBraceComment = 'reached'
}

Task Info {
    Write-Host "DevInfo"
}

Task Deploy {
    Write-Host "Deploy"
}

Task DevOnly {
    Write-Host "DevOnly"
}

Task TestStep1 {
    $myData = $null
    if ($null -ne $properties -and $properties.ContainsKey('myData')) {
        $myData = $properties['myData']
    }
    Write-Host ("Props.myData: {0}" -f $myData)
}

Task TestStep3 {
    Write-Host "TestStep3"
}

Task ShowBoolFlag {
    $value = $boolFlag
    if ($null -ne $properties -and $properties.ContainsKey('boolFlag')) {
        $value = $properties['boolFlag']
    }
    Write-Host ("Props.boolFlag: {0}" -f [bool]$value)
    # The runtime type matters too: the text 'False' casts to $true above.
    Write-Host ("Props.boolFlagType: {0}" -f $(if ($null -eq $boolFlag) { 'null' } else { $boolFlag.GetType().Name }))
}
