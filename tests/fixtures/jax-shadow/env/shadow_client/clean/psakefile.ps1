properties {
    [string]$mcpClient = 'claude'
    [string]$ownParam = 'default'
}

Task NoShadowHere {
    Write-Host ("Props.mcpClient: {0}" -f $mcpClient)
}
