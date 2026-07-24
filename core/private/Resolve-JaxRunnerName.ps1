function Resolve-JaxRunnerName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $normalized = $Name.ToLower()
    switch ($normalized) {
        'pwsh' { return 'pwshscript' }
        'powershell' { return 'pwshscript' }
        'ps1' { return 'pwshscript' }
        'script' { return 'pwshscript' }
        'pwshscript' { return 'pwshscript' }
        'bash' { return 'bashscript' }
        'sh' { return 'bashscript' }
        'bashscript' { return 'bashscript' }
        'cmd' { return 'cmdscript' }
        'bat' { return 'cmdscript' }
        'batch' { return 'cmdscript' }
        'cmdscript' { return 'cmdscript' }
        'nativepsaketask' { return 'psake' }
        'psake' { return 'psake' }
        'bossscenario' { return 'scenario' }
        'boss-scenario' { return 'scenario' }
        'sceny' { return 'scenario' }
        'scenario' { return 'scenario' }
        'docker' { return 'container' }
        'container' { return 'container' }
        default { return $normalized }
    }
}
