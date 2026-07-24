function Get-JaxVaultTokenPath {
    [CmdletBinding()]
    param(
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [System.Collections.IDictionary] $Config
    )

    if ($null -eq $Config) {
        $Config = Get-JaxConfig -RepoRoot $RepoRoot
    }

    $tokenDir = $null
    $vaultCfg = $null
    try { $vaultCfg = Get-JaxVaultPluginConfig -RepoRoot $RepoRoot -Config $Config } catch {}

    if ($vaultCfg -and $vaultCfg.Contains('tokenDir') -and $vaultCfg['tokenDir'] -is [string] -and -not [string]::IsNullOrWhiteSpace($vaultCfg['tokenDir'])) {
        $tokenDir = $vaultCfg['tokenDir'].Trim()
        # Allow shorthand tokenDir='project-key' meaning '.jax/project-key/vault'.
        $hasSeparators = $tokenDir.Contains('/') -or $tokenDir.Contains('\\')
        $looksLikeRelative = $tokenDir.StartsWith('.')
        if (-not $hasSeparators -and -not $looksLikeRelative -and -not [System.IO.Path]::IsPathRooted($tokenDir)) {
            $tokenDir = (Join-Path '.jax' (Join-Path $tokenDir 'vault'))
        }
        if (-not [System.IO.Path]::IsPathRooted($tokenDir)) {
            $tokenDir = Join-Path $HOME $tokenDir
        }
    } else {
        $tokenStoreKey = $null
        if ($vaultCfg -and $vaultCfg.Contains('tokenStoreKey') -and $vaultCfg['tokenStoreKey'] -is [string] -and -not [string]::IsNullOrWhiteSpace($vaultCfg['tokenStoreKey'])) {
            $tokenStoreKey = $vaultCfg['tokenStoreKey'].Trim()
        }

        if ([string]::IsNullOrWhiteSpace($tokenStoreKey)) {
            $tokenDir = Join-Path $HOME '.jax/vault'
        } else {
            # Example: tokenStoreKey=project-key -> ~/.jax/project-key/vault/token.
            $tokenDir = Join-Path $HOME (Join-Path '.jax' (Join-Path $tokenStoreKey 'vault'))
        }
    }

    return (Join-Path $tokenDir 'token')
}
