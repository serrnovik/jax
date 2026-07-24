function Initialize-JaxCliParameterRegistry {
    [CmdletBinding()]
    param ()

    if (-not (Get-Variable -Name JaxCliParameterRegistry -Scope Script -ErrorAction SilentlyContinue)) {
        $script:JaxCliParameterRegistry = @()
    }
    if (-not (Get-Variable -Name JaxCliParameterDefaultsAdded -Scope Script -ErrorAction SilentlyContinue)) {
        $script:JaxCliParameterDefaultsAdded = $false
    }

    if ($script:JaxCliParameterDefaultsAdded) {
        return
    }

    $script:JaxCliParameterDefaultsAdded = $true

    Register-JaxCliParameter -Name 'env' -Aliases @('e') -Type 'string' -Scope 'core'
    Register-JaxCliParameter -Name 'client' -Aliases @() -Type 'string' -Scope 'core'
    Register-JaxCliParameter -Name 'only' -Aliases @('o') -Type 'string' -Scope 'core'
    Register-JaxCliParameter -Name 'from' -Aliases @('f') -Type 'string' -Scope 'core'
    Register-JaxCliParameter -Name 'to' -Aliases @('t') -Type 'string' -Scope 'core'
    Register-JaxCliParameter -Name 'scenario' -Aliases @('s') -Type 'string' -Scope 'core'
    Register-JaxCliParameter -Name 'noBuild' -Aliases @('nb') -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'buildChainOnly' -Aliases @('bo') -Type 'switch' -Scope 'core'

    Register-JaxCliParameter -Name 'dryRun' -Aliases @() -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'plan' -Aliases @('dryRunShort') -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'dryRunDeep' -Aliases @() -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'noCache' -Aliases @() -Type 'switch' -Scope 'core'

    Register-JaxCliParameter -Name 'listTasks' -Aliases @('list') -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'listScenarios' -Aliases @() -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'printCurrentEnv' -Aliases @('getEnv') -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'noTasksDiscovery' -Aliases @('noTasks') -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'noScriptsDiscovery' -Aliases @('noScripts') -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'noScenarioDiscovery' -Aliases @('noSceny') -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'noSavedSettings' -Aliases @('noSave', 'nss') -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'override' -Aliases @() -Type 'string' -Scope 'core'
    Register-JaxCliParameter -Name 'overrides' -Aliases @() -Type 'string' -Scope 'core'
    Register-JaxCliParameter -Name 'docker' -Aliases @('d') -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'container' -Aliases @() -Type 'switch' -Scope 'core'

    Register-JaxCliParameter -Name 'dv' -Aliases @() -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'verbose' -Aliases @() -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'debug' -Aliases @() -Type 'switch' -Scope 'core'

    # Vault toggle (plugin preference): allow users to temporarily disable Vault resolution
    # without disabling the plugin in config.
    Register-JaxCliParameter -Name 'vault' -Aliases @('withVault') -Type 'switch' -Scope 'vault'
    # NOTE: do NOT include 'noVault' as an alias: PowerShell treats parameter names/aliases as case-insensitive,
    # so alias 'noVault' conflicts with name 'novault' (same letters) and breaks DynamicParam metadata generation.
    Register-JaxCliParameter -Name 'novault' -Aliases @('no-vault', 'withoutVault', 'noVaultSecrets') -Type 'switch' -Scope 'vault'
    Register-JaxCliParameter -Name 'vaultToken' -Aliases @() -Type 'string' -Scope 'vault'
    Register-JaxCliParameter -Name 'vaultTokenEnv' -Aliases @('vte') -Type 'string' -Scope 'vault'
    Register-JaxCliParameter -Name 'useEnvVaultToken' -Aliases @('envVaultToken') -Type 'switch' -Scope 'vault'

    # Coverage toggle (plugin preference): set $env:VITEST_COVERAGE for the run.
    Register-JaxCliParameter -Name 'coverage' -Aliases @('cov', 'withCoverage') -Type 'switch' -Scope 'coverage'
    # NOTE: do NOT include 'noCoverage' as an alias of 'nocoverage' (PowerShell case-insensitivity bug; see vault note above).
    Register-JaxCliParameter -Name 'nocoverage' -Aliases @('nocov', 'no-coverage', 'withoutCoverage') -Type 'switch' -Scope 'coverage'

    Register-JaxCliParameter -Name 'forceReloadModules' -Aliases @('fr', 'frm', 'fmr', 'forceModulesReload' ) -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'clearOutput' -Aliases @('co') -Type 'switch' -Scope 'core'
    Register-JaxCliParameter -Name 'beep' -Aliases @('be') -Type 'switch' -Scope 'core'
}
