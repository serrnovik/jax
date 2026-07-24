function Format-JaxPathLink {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path,
        [string] $Label,
        [switch] $Disable
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $display = if ([string]::IsNullOrWhiteSpace($Label)) { $Path } else { $Label }
    if ($Disable -or $env:JAX_DISABLE_LINKS -eq '1') {
        return $display
    }

    $resolved = $Path
    try {
        $resolved = (Resolve-Path -Path $Path -ErrorAction Stop).Path
    } catch {
    }

    $uri = $null
    try {
        $uri = [System.Uri]::new($resolved)
    } catch {
        $uri = $null
    }
    if ($null -eq $uri -or -not $uri.IsAbsoluteUri -or $uri.Scheme -ne 'file') {
        try {
            $uri = [System.Uri]::new("file:///$($resolved -replace '\\', '/')")
        } catch {
            return $display
        }
    }

    $esc = [char]27
    $bel = [char]7
    return "$esc]8;;$($uri.AbsoluteUri)$bel$display$esc]8;;$bel"
}
