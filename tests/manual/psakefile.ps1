task default -depends Test1

task Test1 {
    Write-Host ">>> TASK EXECUTED: Test1"
    Write-Host ">>> Props.stepName: $($properties.stepName)"
    Write-Host ">>> Props.myData: $($properties.myData)"
}

task Test2 {
    Write-Host ">>> TASK EXECUTED: Test2"
    Write-Host ">>> Props.stepName: $($properties.stepName)"
    Write-Host ">>> Props.myData: $($properties.myData)"
}
