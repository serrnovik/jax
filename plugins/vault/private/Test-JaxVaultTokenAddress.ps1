function Get-JaxVaultTokenAddressPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $TokenPath
    )

    # Non-secret sidecar: the Vault address the saved token was issued by.
    return (Join-Path (Split-Path -Parent $TokenPath) 'address')
}

function Test-JaxVaultTokenAddress {
    <#
    .SYNOPSIS
    Compares the address saved next to a token with the configured address.

    .OUTPUTS
    A hashtable with SavedAddress, ConfiguredAddress and Mismatch. Mismatch is
    true only when both addresses are known and differ.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $TokenPath,
        [string] $ConfiguredAddress,
        [switch] $Warn
    )

    $saved = $null
    $addressPath = Get-JaxVaultTokenAddressPath -TokenPath $TokenPath
    if (Test-Path -LiteralPath $addressPath -PathType Leaf) {
        try { $saved = ([string](Get-Content -LiteralPath $addressPath -Raw -ErrorAction Stop)).Trim() } catch {}
    }

    $normalize = { param($value) if ([string]::IsNullOrWhiteSpace($value)) { $null } else { ([string]$value).Trim().TrimEnd('/').ToLowerInvariant() } }
    $savedNorm = & $normalize $saved
    $configuredNorm = & $normalize $ConfiguredAddress
    $mismatch = ($null -ne $savedNorm) -and ($null -ne $configuredNorm) -and ($savedNorm -ne $configuredNorm)

    if ($Warn -and $mismatch) {
        if ($null -eq $script:JaxVaultAddressWarned) { $script:JaxVaultAddressWarned = @{} }
        if (-not $script:JaxVaultAddressWarned.ContainsKey($TokenPath)) {
            $script:JaxVaultAddressWarned[$TokenPath] = $true
            Write-Warning "Vault token at '$TokenPath' was issued by '$saved', but this repository uses '$ConfiguredAddress'. Run 'jx vault login' in this repository."
        }
    }

    return @{
        SavedAddress      = $saved
        ConfiguredAddress = $ConfiguredAddress
        Mismatch          = $mismatch
    }
}
