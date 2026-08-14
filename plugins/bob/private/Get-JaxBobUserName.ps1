<#
.SYNOPSIS
    Who the per-developer config layer is for.

.DESCRIPTION
    JAX_USER wins, so a shared account, a container, or a CI box can say whose
    profile it is standing in for. Otherwise the OS user name, which is what the
    file is named after on the machine where it was written.

    Lowercased: `Sno` on Windows and `sno` on macOS are one person, and a config
    layer that loads on one machine and silently does not on the other is worse
    than no layer at all.
#>
function Get-JaxBobUserName {
    [CmdletBinding()]
    param ()

    foreach ($candidate in @($env:JAX_USER, $env:USER, $env:USERNAME, $env:LOGNAME)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            return $candidate.Trim().ToLowerInvariant()
        }
    }

    return ''
}
