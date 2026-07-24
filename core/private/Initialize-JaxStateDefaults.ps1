function Initialize-JaxStateDefaults {
    [CmdletBinding()]
    param ()

    if (-not (Get-Variable -Name JaxStateDefaults -Scope Script -ErrorAction SilentlyContinue)) {
        $script:JaxStateDefaults = @{}
    }

    if (-not $script:JaxStateDefaults.ContainsKey('core')) {
        $script:JaxStateDefaults['core'] = @{}
    }

    if ($script:JaxStateDefaults['core'].Keys.Count -eq 0) {
        Register-JaxPersistentSetting -Scope 'core' -Key 'env' -Default $null
        Register-JaxPersistentSetting -Scope 'core' -Key 'client' -Default $null
        Register-JaxPersistentSetting -Scope 'core' -Key 'scenario' -Default $null
        Register-JaxPersistentSetting -Scope 'core' -Key 'from' -Default $null
        Register-JaxPersistentSetting -Scope 'core' -Key 'to' -Default $null
        Register-JaxPersistentSetting -Scope 'core' -Key 'docker' -Default $false
        Register-JaxPersistentSetting -Scope 'core' -Key 'container' -Default $false
        Register-JaxPersistentSetting -Scope 'core' -Key 'dryRun' -Default $false
        Register-JaxPersistentSetting -Scope 'core' -Key 'verbose' -Default $false
        Register-JaxPersistentSetting -Scope 'core' -Key 'quiet' -Default $false
    }

    # Plugin preferences (persisted toggles). These are NOT execution selectors; they represent user defaults.
    if (-not $script:JaxStateDefaults.ContainsKey('plugins')) {
        $script:JaxStateDefaults['plugins'] = @{}
    }
    if ($script:JaxStateDefaults['plugins'].Keys.Count -eq 0) {
        Register-JaxPersistentSetting -Scope 'plugins' -Key 'vault' -Default @{ enabled = $null }
        Register-JaxPersistentSetting -Scope 'plugins' -Key 'coverage' -Default @{ enabled = $null }
    }
}
