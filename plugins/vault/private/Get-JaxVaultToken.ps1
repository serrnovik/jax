function Get-JaxVaultToken {
    [CmdletBinding()]
    param()

    # Priority:
    # 1) Vault Agent Injector token at /vault/secrets/token (always trusted —
    #    presence of this file means the pod ran the injector init container,
    #    which is the canonical CI auth path on Kubernetes runners). No
    #    config opt-in required: this path is never world-readable in a
    #    correctly-configured pod and only exists when the injector wrote it.
    # 2) Env var VAULT_TOKEN when explicitly allowed (config opt-in)
    # 3) Saved token file (~/.jax/vault/token)
    $injectorTokenPath = Get-JaxVaultInjectorTokenPath
    if ($injectorTokenPath -and (Test-Path -LiteralPath $injectorTokenPath)) {
        try {
            $injected = Get-Content -LiteralPath $injectorTokenPath -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($injected)) {
                return $injected.Trim()
            }
        } catch {}
    }

    $allowEnvToken = $false
    try {
        $vaultCfg = Get-JaxVaultPluginConfig
        if ($vaultCfg -and $vaultCfg.Contains('allowEnvToken') -and $vaultCfg['allowEnvToken'] -is [bool] -and $vaultCfg['allowEnvToken']) {
            $allowEnvToken = $true
        }
    } catch {
        # best-effort
    }
    if ($allowEnvToken -and (Test-Path Env:\VAULT_TOKEN)) {
        $val = (Get-Item Env:\VAULT_TOKEN).Value
        if (-not [string]::IsNullOrWhiteSpace($val)) {
            return $val
        }
    }

    # 2b) AppRole login from VAULT_ROLE_ID / VAULT_SECRET_ID in the environment.
    #     Presence-based like the injector path (no config opt-in): operators set
    #     these only on runners without a Kubernetes pod identity. Each invocation
    #     gets a fresh short-TTL token. Requires VAULT_ADDR and the `vault` CLI.
    if ((Test-Path Env:\VAULT_ROLE_ID) -and (Test-Path Env:\VAULT_SECRET_ID)) {
        $roleId = (Get-Item Env:\VAULT_ROLE_ID).Value
        $secretId = (Get-Item Env:\VAULT_SECRET_ID).Value
        if (-not [string]::IsNullOrWhiteSpace($roleId) -and -not [string]::IsNullOrWhiteSpace($secretId)) {
            try {
                $vaultCmd = Get-Command vault -ErrorAction SilentlyContinue
                if ($vaultCmd) {
                    $json = & $vaultCmd.Source write -format=json auth/approle/login role_id=$roleId secret_id=$secretId 2>$null
                    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($json)) {
                        $tok = ($json | ConvertFrom-Json).auth.client_token
                        if (-not [string]::IsNullOrWhiteSpace($tok)) {
                            return $tok
                        }
                    }
                }
            } catch {
                # best-effort: fall through to the saved-token path
            }
        }
    }

    $tokenPath = Get-JaxVaultTokenPath
    if (Test-Path $tokenPath) {
        try {
            # Simple storage for now, rely on FS permissions.
            # Ideally use DPAPI/Keychain but cross-platform logic is complex in pure PS.
            $token = Get-Content -Path $tokenPath -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($token)) {
                return $token.Trim()
            }
        } catch {}
    }

    return $null
}
