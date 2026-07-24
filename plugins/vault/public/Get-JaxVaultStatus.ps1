function Get-JaxVaultStatus {
    [CmdletBinding()]
    param()

    $repoRoot = Get-JaxRepoRoot
    $config = Get-JaxConfig -RepoRoot $repoRoot
    $tokenPath = Get-JaxVaultTokenPath -RepoRoot $repoRoot -Config $config

    $vaultCfg = $null
    try { $vaultCfg = Get-JaxVaultPluginConfig } catch {}
    $cfgAddr = $null
    $cfgPolicy = $null
    $secretCheckPath = 'secret/hello'
    if ($vaultCfg -and $vaultCfg.Contains('address') -and $vaultCfg['address'] -is [string] -and -not [string]::IsNullOrWhiteSpace($vaultCfg['address'])) {
        $cfgAddr = $vaultCfg['address']
    }
    if ($vaultCfg -and $vaultCfg.Contains('policy') -and $vaultCfg['policy'] -is [string] -and -not [string]::IsNullOrWhiteSpace($vaultCfg['policy'])) {
        $cfgPolicy = $vaultCfg['policy']
    }
    if ($vaultCfg -and $vaultCfg.Contains('secretCheckPath') -and $vaultCfg['secretCheckPath'] -is [string] -and -not [string]::IsNullOrWhiteSpace($vaultCfg['secretCheckPath'])) {
        $secretCheckPath = $vaultCfg['secretCheckPath']
    }
    $secretMount = 'secret'
    $secretPath = 'hello'
    if ($secretCheckPath -match '^(?<mount>[^/]+)/(?<path>.+)$') {
        $secretMount = $Matches['mount']
        $secretPath = $Matches['path']
    }

    $addr = $cfgAddr
    if ([string]::IsNullOrWhiteSpace($addr) -and (Test-Path Env:\VAULT_ADDR)) {
        $addr = (Get-Item Env:\VAULT_ADDR).Value
    }
    if ([string]::IsNullOrWhiteSpace($addr)) {
        $addr = "Not Set"
    }

    $token = Get-JaxVaultToken
    $tokenStatus = if (-not [string]::IsNullOrWhiteSpace($token)) { "Present (Length: $($token.Length))" } else { "Not Found" }

    Write-Host "Vault Status" -ForegroundColor Cyan
    Write-Host "------------"
    Write-Host "Address: $addr"
    Write-Host "Token:   $tokenStatus"
    Write-Host "Token path: $tokenPath"
    if (-not [string]::IsNullOrWhiteSpace($cfgPolicy)) {
        Write-Host "Policy: $cfgPolicy"
    }

    # Best-effort: show token expiry info when we have address + token.
    if (-not [string]::IsNullOrWhiteSpace($addr) -and -not [string]::IsNullOrWhiteSpace($token)) {
        $oldAddr = $env:VAULT_ADDR
        $oldToken = $env:VAULT_TOKEN
        try {
            $env:VAULT_ADDR = $addr
            $env:VAULT_TOKEN = $token

            # Vault CLI versions differ:
            # - newer: `vault token lookup-self`
            # - some:  `vault token lookup -self`
            # - older: `vault token lookup` (with no token arg, uses VAULT_TOKEN)
            $lookupOut = & vault token lookup-self -format=json 2>&1
            $lookupExit = $LASTEXITCODE
            if ($lookupExit -ne 0 -or -not $lookupOut) {
                $lookupOut = & vault token lookup -self -format=json 2>&1
                $lookupExit = $LASTEXITCODE
            }
            if ($lookupExit -ne 0 -or -not $lookupOut) {
                $lookupOut = & vault token lookup -format=json 2>&1
                $lookupExit = $LASTEXITCODE
            }
            if ($lookupExit -ne 0 -or -not $lookupOut) {
                $details = if ($lookupOut) { ([string]$lookupOut).Trim() } else { '' }
                Write-Warning "Unable to lookup token info (exit: $lookupExit). Vault said: $details"
                return
            }

            $data = $lookupOut | ConvertFrom-Json -ErrorAction Stop
            if (-not $data -or -not $data.data) {
                return
            }

            $ttlSeconds = $null
            if ($data.data.PSObject.Properties.Name -contains 'ttl') {
                $ttlSeconds = $data.data.ttl
            }
            $expireTimeRaw = $null
            if ($data.data.PSObject.Properties.Name -contains 'expire_time') {
                $expireTimeRaw = $data.data.expire_time
            }

            if ($null -ne $ttlSeconds) {
                Write-Host ("TTL (seconds): {0}" -f $ttlSeconds)
                try {
                    $ttlSpan = [TimeSpan]::FromSeconds([double]$ttlSeconds)
                    $ttlDays = [int][Math]::Floor($ttlSpan.TotalDays)
                    $ttlHours = $ttlSpan.Hours
                    $ttlMinutes = $ttlSpan.Minutes
                    $ttlSecondsInt = $ttlSpan.Seconds
                    if ($ttlDays -gt 0) {
                        Write-Host ("TTL: {0}d {1}h {2}m {3}s" -f $ttlDays, $ttlHours, $ttlMinutes, $ttlSecondsInt)
                    } else {
                        Write-Host ("TTL: {0}h {1}m {2}s" -f ([int]$ttlSpan.TotalHours), $ttlMinutes, $ttlSecondsInt)
                    }
                } catch {
                    # best-effort
                }
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$expireTimeRaw)) {
                Write-Host ("Expire time: {0}" -f $expireTimeRaw)
                try {
                    $expireAt = [datetime]::Parse([string]$expireTimeRaw, [System.Globalization.CultureInfo]::InvariantCulture)
                    $remaining = $expireAt.ToUniversalTime() - [datetime]::UtcNow
                    if ($remaining.TotalSeconds -lt 0) {
                        Write-Host "Expires in: EXPIRED" -ForegroundColor Yellow
                    } else {
                        $days = [int][Math]::Floor($remaining.TotalDays)
                        $hours = $remaining.Hours
                        $minutes = $remaining.Minutes
                        $seconds = $remaining.Seconds
                        if ($days -gt 0) {
                            Write-Host ("Expires in: {0}d {1}h {2}m {3}s" -f $days, $hours, $minutes, $seconds)
                        } else {
                            Write-Host ("Expires in: {0}h {1}m {2}s" -f ([int]$remaining.TotalHours), $minutes, $seconds)
                        }
                    }
                } catch {
                    # best-effort: leave as raw string
                }
            }

            # Simple live checks to validate token access (keys only).
            # 1) Expected secret presence (do not print secret values).
            $secretOk = $false
            $null = & vault kv get -format=json $secretCheckPath 2>&1
            $getExit = $LASTEXITCODE
            if ($getExit -eq 0) {
                $secretOk = $true
            } else {
                $null = & vault kv get -mount $secretMount -format=json $secretPath 2>&1
                $getExit = $LASTEXITCODE
                if ($getExit -eq 0) { $secretOk = $true }
            }
            $secretStatus = if ($secretOk) { '✅' } else { '❌' }
            Write-Host "Secret check ($secretCheckPath): $secretStatus"

            # 2) List root keys under the secret mount (does not output values).
            $listOut = & vault kv list -format=json "$secretMount/" 2>&1
            $listExit = $LASTEXITCODE
            if ($listExit -ne 0 -or -not $listOut) {
                $listOut = & vault kv list "-mount=$secretMount" -format=json / 2>&1
                $listExit = $LASTEXITCODE
            }
            if ($listExit -eq 0 -and $listOut) {
                Write-Host "Secret keys under $secretMount/:" -ForegroundColor Cyan
                Write-Host ([string]$listOut).Trim()
            } else {
                $details = if ($listOut) { ([string]$listOut).Trim() } else { '' }
                Write-Warning "Unable to list $secretMount/ keys (exit: $listExit). Vault said: $details"
            }
        } catch {
            Write-Warning "Failed to retrieve token expiry info: $_"
        } finally {
            $env:VAULT_ADDR = $oldAddr
            $env:VAULT_TOKEN = $oldToken
        }
    }
}
