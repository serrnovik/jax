properties {
    # `client` is a name Jax binds for itself (the <client>/<env> selector), so it
    # can never arrive from the command line. Declared here on purpose: the tests
    # assert Jax says so instead of running the task with this default.
    [string]$client = 'claude'
    [string]$ownParam = 'default'
}

Task ShowShadowedParam {
    Write-Host ("Props.client: {0}" -f $client)
    Write-Host ("Props.ownParam: {0}" -f $ownParam)
}
