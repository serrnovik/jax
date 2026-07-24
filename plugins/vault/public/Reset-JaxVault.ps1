function Reset-JaxVault {
    [CmdletBinding()]
    param()

    # Use the configured token path (supports plugins.config.vault.tokenDir / tokenStoreKey).
    $repoRoot = Get-JaxRepoRoot
    $config = Get-JaxConfig -RepoRoot $repoRoot
    $tokenPath = Get-JaxVaultTokenPath -RepoRoot $repoRoot -Config $config
    if (Test-Path $tokenPath) {
        Remove-Item -Path $tokenPath -Force -ErrorAction SilentlyContinue
        Write-Host "Cleared stored Vault token." -ForegroundColor Yellow
    }

    $env:VAULT_TOKEN = $null
    Write-Host "Cleared session VAULT_TOKEN." -ForegroundColor Yellow
}
