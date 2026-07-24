function Resolve-JaxScriptRunnerName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ScriptPath
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $extension = [IO.Path]::GetExtension($ScriptPath).ToLowerInvariant()
    switch ($extension) {
        '.ps1' { return 'pwshscript' }
        '.psm1' { return 'pwshscript' }
        '.sh' { return 'bashscript' }
        '.bash' { return 'bashscript' }
        '.cmd' { return 'cmdscript' }
        '.bat' { return 'cmdscript' }
        default { return 'pwshscript' }
    }
}
