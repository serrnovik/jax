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
