function Get-JaxVaultEnv {
    <#
    .SYNOPSIS
    Emits shell code that sets VAULT_ADDR and VAULT_TOKEN from this repository's
    own Vault token, so a bare `vault` command never falls back to the shared
    ~/.vault-token.

    .DESCRIPTION
    The output contains the token. Evaluate it; do not print it:
      pwsh: jx vault env | Out-String | Invoke-Expression
      bash: eval "$(jx vault env bash)"
    Status messages go to stderr so they never mix with the evaluated code.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('pwsh', 'bash', 'sh', 'zsh')]
        [string] $Shell = 'pwsh'
    )

    $repoRoot = Get-JaxRepoRoot
    $config = Get-JaxConfig -RepoRoot $repoRoot
    $vaultCfg = $null
    try { $vaultCfg = Get-JaxVaultPluginConfig -RepoRoot $repoRoot -Config $config } catch {}

    $address = $null
    if ($vaultCfg -and $vaultCfg.Contains('address') -and $vaultCfg['address'] -is [string] -and -not [string]::IsNullOrWhiteSpace($vaultCfg['address'])) {
        $address = ([string]$vaultCfg['address']).Trim()
    }

    $tokenPath = Get-JaxVaultTokenPath -RepoRoot $repoRoot -Config $config
    $token = $null
    if (Test-Path -LiteralPath $tokenPath -PathType Leaf) {
        try { $token = ([string](Get-Content -LiteralPath $tokenPath -Raw -ErrorAction Stop)).Trim() } catch {}
    }

    $check = Test-JaxVaultTokenAddress -TokenPath $tokenPath -ConfiguredAddress $address
    if ($check.Mismatch) {
        [Console]::Error.WriteLine("jax: warning: Vault token at '$tokenPath' was issued by '$($check.SavedAddress)', but this repository uses '$address'. Run 'jx vault login' in this repository.")
    }
    if ([string]::IsNullOrWhiteSpace($token)) {
        [Console]::Error.WriteLine("jax: no Vault token at '$tokenPath'. Run 'jx vault login' in this repository.")
    }

    $isPwsh = $Shell -eq 'pwsh'
    $quote = if ($isPwsh) {
        { param($v) "'" + ([string]$v).Replace("'", "''") + "'" }
    } else {
        { param($v) "'" + ([string]$v).Replace("'", "'\''") + "'" }
    }
    $set = if ($isPwsh) {
        { param($name, $v) "`$env:$name = $(& $quote $v)" }
    } else {
        { param($name, $v) "export $name=$(& $quote $v)" }
    }
    $unset = if ($isPwsh) {
        { param($name) "Remove-Item Env:\$name -ErrorAction SilentlyContinue" }
    } else {
        { param($name) "unset $name" }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($address)) {
        $lines.Add((& $set 'VAULT_ADDR' $address)) | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace($token)) {
        $lines.Add((& $set 'VAULT_TOKEN' $token)) | Out-Null
    } else {
        # Never leave a token from another repository in place.
        $lines.Add((& $unset 'VAULT_TOKEN')) | Out-Null
    }
    return @($lines)
}
