function Get-JaxGalleryStatus {
    <#
    .SYNOPSIS
        Ask a specific Jax runtime how it compares to the published release.
    .DESCRIPTION
        Get-JaxUpdateStatus lives in the root module (Jax.psm1), not in Jax.Core,
        and it reports the version of the module it is *defined in*. Calling it by
        bare name from core is therefore worse than it looks: PowerShell autoloads
        whatever Jax PSModulePath happens to offer, which on a machine carrying a
        stale `Install-Module Jax` is the exact copy `jax update` exists to clean
        up - and the answer comes back describing that copy instead of the one the
        user is running.

        So the function is resolved out of the runtime we were handed. Already
        loaded from that base, it is reused; otherwise its manifest is imported by
        path. Either way the answer describes the runtime named in RuntimeRoot.
    .PARAMETER RuntimeRoot
        Directory holding the Jax.psd1 whose Get-JaxUpdateStatus should answer.
    .PARAMETER Force
        Bypass the 24h version cache.
    .OUTPUTS
        The Get-JaxUpdateStatus result, or $null when the runtime cannot answer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RuntimeRoot,

        [switch] $Force
    )

    $root = try { [IO.Path]::GetFullPath($RuntimeRoot) } catch { $RuntimeRoot }

    $module = Get-Module -Name 'Jax' |
        Where-Object { [IO.Path]::GetFullPath($_.ModuleBase) -eq $root } |
        Select-Object -First 1

    if ($null -eq $module) {
        $manifest = Join-Path $root 'Jax.psd1'
        if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { return $null }
        try {
            $module = Import-Module -Name $manifest -PassThru -Force -DisableNameChecking -ErrorAction Stop
        } catch {
            return $null
        }
    }

    try {
        return (& $module { param($ForceRefresh) Get-JaxUpdateStatus -Force:$ForceRefresh } $Force)
    } catch {
        return $null
    }
}
