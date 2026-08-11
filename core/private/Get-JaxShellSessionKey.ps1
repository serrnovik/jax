function Get-JaxShellSessionKey {
    <#
    .SYNOPSIS
        Identify the shell session a Jax command was launched from.
    .DESCRIPTION
        The zsh/bash shims run a fresh pwsh per command, so $PID changes on
        every invocation and cannot mark "already told this session". The shims
        export JAX_SHELL_SESSION with the calling shell's PID, which is stable
        for the life of that terminal. In PowerShell, Jax runs in-process and
        $PID already identifies the session.
    #>
    [CmdletBinding()]
    param ()

    $shellSession = [string]$env:JAX_SHELL_SESSION
    if (-not [string]::IsNullOrWhiteSpace($shellSession)) {
        return "shell-$($shellSession.Trim())"
    }

    return "pwsh-$PID"
}
