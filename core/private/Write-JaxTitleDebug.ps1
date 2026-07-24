function Write-JaxTitleDebug {
    <#
    .SYNOPSIS
        Opt-in diagnostic logger for the terminal/cmux tab-title feature.
    .DESCRIPTION
        No-op unless $env:JAX_TITLE_DEBUG is set. Appends one timestamped line per
        call to <temp>/jax-title-debug.log so the set/capture/restore flow can be
        inspected after a real run (the live process otherwise swallows all errors).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Message
    )

    if (-not $env:JAX_TITLE_DEBUG) { return }

    try {
        $logPath = Join-Path $HOME 'jax-title-debug.log'
        $stamp = (Get-Date).ToString('HH:mm:ss.fff')
        Add-Content -Path $logPath -Value "[$stamp][pid:$PID] $Message" -ErrorAction SilentlyContinue
    }
    catch {}
}
