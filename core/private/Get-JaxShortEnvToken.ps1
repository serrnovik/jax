function Get-JaxShortEnvToken {
    <#
    .SYNOPSIS
        Shorten an env name to a compact tab token: the most meaningful path segment,
        truncated to N chars with a single-char ellipsis when needed.
    .DESCRIPTION
        jax env identifiers are not consistently shaped — some are "<client>/<flow>"
        (e.g. "demo-app/build") and some are "<flow>/<name>" (e.g. "build/wtw").
        Either way the FLOW is already shown as an emoji in the title, so we drop any
        flow-like segment and keep the first remaining (the real env name):

            demo-app/build  -> demo-…     (drop "build")
            build/wtw          -> wtw         (drop "build")
            sample-app/pack -> sampl…      (drop "pack")
            dev                -> dev

        Returns '' when there is no usable env name, so callers can omit the token.
    .PARAMETER EnvName
        The env identifier (may contain '/').
    .PARAMETER FlowName
        The flow, when known separately — also dropped from the segments.
    .PARAMETER KnownFlows
        Flow keywords to drop. Defaults cover the built-in jax flow icons plus common
        variants.
    #>
    [CmdletBinding()]
    param(
        [string] $EnvName,
        [string] $FlowName,
        [int] $Length = 5,
        [string[]] $KnownFlows = @('build', 'pack', 'play', 'test', 'dryrun', 'publish')
    )

    if ([string]::IsNullOrWhiteSpace($EnvName)) { return '' }

    $segments = @(
        $EnvName -split '/' |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    if ($segments.Count -eq 0) { return '' }

    $drop = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($k in $KnownFlows) { [void] $drop.Add($k) }
    if ($FlowName) { [void] $drop.Add($FlowName.Trim()) }

    $meaningful = @($segments | Where-Object { -not $drop.Contains($_) })
    $pick = if ($meaningful.Count -gt 0) { $meaningful[0] } else { $segments[-1] }

    if ($Length -le 0 -or $pick.Length -le $Length) { return $pick }
    return $pick.Substring(0, $Length) + '…'
}
