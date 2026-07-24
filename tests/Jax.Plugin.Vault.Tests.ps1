$here = Split-Path -Parent $MyInvocation.MyCommand.Path
# Load core modules
$jaxRoot = Resolve-Path (Join-Path $here '..')
Import-Module (Join-Path $jaxRoot 'core/Jax.Core.psm1') -Global -Force

# Load Vault Plugin
$pluginRoot = Join-Path $jaxRoot 'plugins/vault'
$pluginPath = Join-Path $pluginRoot 'Jax.Plugin.Vault.psm1'
Write-Host "Loading Vault Plugin from: $pluginPath"
Import-Module $pluginPath -Global -Force

Describe "Jax.Plugin.Vault" {
    BeforeAll {
        $script:removeVaultTestStub = -not [bool](Get-Command vault -ErrorAction SilentlyContinue)
        if ($script:removeVaultTestStub) {
            function global:vault {
                $global:LASTEXITCODE = 1
                return 'vault test stub'
            }
        }
    }

    AfterAll {
        if ($script:removeVaultTestStub) {
            Remove-Item Function:\global:vault -ErrorAction SilentlyContinue
        }
    }

    InModuleScope 'Jax.Plugin.Vault' {
        Context "Resolve-JaxVaultSecrets" {
            It "Should return original string if no secret pattern" {
                $input = "plain text"
                $result = Resolve-JaxVaultSecrets -Data $input
                $result | Should -Be "plain text"
            }

            It "Should resolve multiple secrets in a string" {
                # Mock Vault CLI - tough without mocking 'vault' command.
                # But we can assume Cache hit mocks it.
                $cache = @{
                    'kv:secret/mydata' = @{ 'mykey' = 'secret_value' }
                }

                $inputData = "Value is << kv2|kv:secret/mydata:mykey >>"
                $result = Resolve-JaxVaultSecrets -Data $inputData -Cache $cache

                $result | Should -Be "Value is secret_value"
            }

            It "Should recurse into hashtables" {
                $cache = @{ 'kv:foo' = @{ 'bar' = 'baz' } }
                $input = @{
                    'A' = 'normal'
                    'B' = '<< kv2|kv:foo:bar >>'
                    'C' = @{
                        'D' = '<< kv2|kv:foo:bar >>'
                    }
                }

                $result = Resolve-JaxVaultSecrets -Data $input -Cache $cache
                $result['B'] | Should -Be 'baz'
                $result['C']['D'] | Should -Be 'baz'
            }

            It "Should recurse into arrays" {
                $cache = @{ 'kv:foo' = @{ 'bar' = 'baz' } }
                $input = @('plain', '<< kv2|kv:foo:bar >>')

                $result = Resolve-JaxVaultSecrets -Data $input -Cache $cache
                $result[1] | Should -Be 'baz'
            }
        }

        Context "RunConfig secret resolution via hook" {
            It "Resolves secrets in Context.RunConfig before a run entity executes" {
                InModuleScope Jax.Core {
                    # Ensure clean registry and plugin loaded state in this module scope.
                    $script:JaxPluginRegistry = @()
                    $script:JaxPluginsLoaded = $true
                }

                # Register vault plugin again (it auto-registers on import, but we want deterministic registry for this test)
                Register-JaxVaultPlugin | Out-Null

                Mock vault {
                    # Called as: vault kv get -mount=<mount> -format=json <path>
                    $global:LASTEXITCODE = 0
                    return '{"data":{"data":{"OPENAI_API_KEY":"resolved-secret"}}}'
                }

                $context = @{
                    Config    = @{
                        plugins = @{
                            enabled  = @('vault')
                            disabled = @()
                            paths    = @()
                            config   = @{
                                vault = @{
                                    enabled = $true
                                    address = 'https://vault.example'
                                }
                            }
                        }
                    }
                    RunConfig = @{
                        secrets = @{
                            ai = @{
                                openai = @{
                                    api_key = '<< kv2|secret:external-services/open-ai:OPENAI_API_KEY >>'
                                }
                            }
                        }
                    }
                }

                Invoke-JaxHooks -Name 'BeforeRunEntity' -Context $context -Data @{ Entity = @{ Args = @{} } }

                $context.RunConfig.secrets.ai.openai.api_key | Should -Be 'resolved-secret'
                $context.RunConfigVaultResolved | Should -Be $true
                $context.VaultSecretsResolved | Should -Be $true
            }
        }

        Context "Vault status diagnostics" {
            It "uses the configured mount for the hello check and root listing" {
                Mock Get-JaxRepoRoot { '/tmp/repo' }
                Mock Get-JaxConfig { @{ } }
                Mock Get-JaxVaultTokenPath { '/tmp/token' }
                Mock Get-JaxVaultPluginConfig {
                    @{
                        address         = 'https://vault.example'
                        secretCheckPath = 'tn1/hello'
                    }
                }
                Mock Get-JaxVaultToken { 'test-token' }

                $script:vaultStatusCalls = @()
                Mock vault {
                    $script:vaultStatusCalls += ,@($args)
                    $global:LASTEXITCODE = 0
                    if ($args -contains 'lookup-self') {
                        return '{"data":{"ttl":3600,"expire_time":"2099-01-01T00:00:00Z","policies":["tn1","tn1-admin"],"path":"auth/github-tn1/login"}}'
                    }
                    if ($args -contains 'list') {
                        return '["hello"]'
                    }
                    return '{}'
                }

                $output = Get-JaxVaultStatus 6>&1 | Out-String

                $calls = @($script:vaultStatusCalls | ForEach-Object { $_ -join ' ' })
                ($calls -join "`n") | Should -Match ([regex]::Escape('kv get -format=json tn1/hello'))
                ($calls -join "`n") | Should -Match ([regex]::Escape('kv list -format=json tn1/'))
                $output | Should -Match 'TTL: 1h'
                $output | Should -Match 'Token policies: tn1, tn1-admin'
                $output | Should -Match 'Auth path: auth/github-tn1/login'
            }

            It "formats long Vault durations for humans" {
                Format-JaxVaultDuration -Duration '87600h' | Should -Be '10y'
                Format-JaxVaultDuration -Seconds 90061 | Should -Be '1d 1h 1m 1s'
                Format-JaxVaultDuration -Duration '1h30m' | Should -Be '1h30m'
            }
        }

        Context "Vault env lifecycle" {
            It "Restores VAULT_* environment after run" {
                InModuleScope Jax.Core {
                    $script:JaxPluginRegistry = @()
                    $script:JaxPluginsLoaded = $true
                }
                Register-JaxVaultPlugin | Out-Null

                Mock Get-JaxVaultToken { 'newtoken' }

                $orig = @{
                    VAULT_ADDR            = @{ WasSet = (Test-Path Env:\VAULT_ADDR); Value = (Get-Item Env:\VAULT_ADDR -ErrorAction SilentlyContinue).Value }
                    VAULT_TOKEN           = @{ WasSet = (Test-Path Env:\VAULT_TOKEN); Value = (Get-Item Env:\VAULT_TOKEN -ErrorAction SilentlyContinue).Value }
                    JAX_NO_CONFIG_SECRETS = @{ WasSet = (Test-Path Env:\JAX_NO_CONFIG_SECRETS); Value = (Get-Item Env:\JAX_NO_CONFIG_SECRETS -ErrorAction SilentlyContinue).Value }
                }
                try {
                    Set-Item -Path Env:\VAULT_ADDR -Value 'https://orig.example' | Out-Null
                    Set-Item -Path Env:\VAULT_TOKEN -Value 'origtoken' | Out-Null
                    Set-Item -Path Env:\JAX_NO_CONFIG_SECRETS -Value '1' | Out-Null

                    $context = @{
                        Config = @{
                            plugins = @{
                                enabled = @('vault')
                                config  = @{
                                    vault = @{
                                        enabled = $true
                                        address = 'https://vault.example'
                                    }
                                }
                            }
                        }
                    }

                    Invoke-JaxHooks -Name 'BeforeRunEntity' -Context $context -Data @{}

                    $env:VAULT_ADDR | Should -Be 'https://vault.example'
                    $env:VAULT_TOKEN | Should -Be 'newtoken'
                    (Test-Path Env:\JAX_NO_CONFIG_SECRETS) | Should -Be $false

                    Invoke-JaxHooks -Name 'AfterRunEntities' -Context $context -Data @{}

                    $env:VAULT_ADDR | Should -Be 'https://orig.example'
                    $env:VAULT_TOKEN | Should -Be 'origtoken'
                    $env:JAX_NO_CONFIG_SECRETS | Should -Be '1'
                } finally {
                    foreach ($name in @('VAULT_ADDR', 'VAULT_TOKEN', 'JAX_NO_CONFIG_SECRETS')) {
                        $snap = $orig[$name]
                        if ($snap.WasSet) {
                            Set-Item -Path "Env:$name" -Value $snap.Value | Out-Null
                        } else {
                            Remove-Item "Env:$name" -ErrorAction SilentlyContinue
                        }
                    }
                }
            }

            It "Uses explicit run vault token over saved token" {
                InModuleScope Jax.Core {
                    $script:JaxPluginRegistry = @()
                    $script:JaxPluginsLoaded = $true
                }
                Register-JaxVaultPlugin | Out-Null

                Mock Get-JaxVaultToken { 'savedtoken' }

                $oldToken = $env:VAULT_TOKEN
                try {
                    $context = @{
                        Config          = @{
                            plugins = @{
                                enabled = @('vault')
                                config  = @{
                                    vault = @{
                                        enabled = $true
                                        address = 'https://vault.example'
                                    }
                                }
                            }
                        }
                        ResolvedOptions = @{
                            vaultToken = 'explicit-token'
                        }
                    }

                    Invoke-JaxHooks -Name 'BeforeRunEntity' -Context $context -Data @{}

                    $env:VAULT_TOKEN | Should -Be 'explicit-token'
                } finally {
                    if ($null -ne $oldToken) {
                        $env:VAULT_TOKEN = $oldToken
                    } else {
                        Remove-Item Env:\VAULT_TOKEN -ErrorAction SilentlyContinue
                    }
                }
            }

            It "Uses explicit run vault token env var over saved token" {
                InModuleScope Jax.Core {
                    $script:JaxPluginRegistry = @()
                    $script:JaxPluginsLoaded = $true
                }
                Register-JaxVaultPlugin | Out-Null

                Mock Get-JaxVaultToken { 'savedtoken' }

                $oldToken = $env:VAULT_TOKEN
                $oldBackupToken = $env:JAX_TEST_BACKUP_VAULT_TOKEN
                try {
                    $env:JAX_TEST_BACKUP_VAULT_TOKEN = 'backup-token'
                    $context = @{
                        Config          = @{
                            plugins = @{
                                enabled = @('vault')
                                config  = @{
                                    vault = @{
                                        enabled = $true
                                        address = 'https://vault.example'
                                    }
                                }
                            }
                        }
                        ResolvedOptions = @{
                            vaultTokenEnv = 'JAX_TEST_BACKUP_VAULT_TOKEN'
                        }
                    }

                    Invoke-JaxHooks -Name 'BeforeRunEntity' -Context $context -Data @{}

                    $env:VAULT_TOKEN | Should -Be 'backup-token'
                } finally {
                    if ($null -ne $oldToken) {
                        $env:VAULT_TOKEN = $oldToken
                    } else {
                        Remove-Item Env:\VAULT_TOKEN -ErrorAction SilentlyContinue
                    }
                    if ($null -ne $oldBackupToken) {
                        $env:JAX_TEST_BACKUP_VAULT_TOKEN = $oldBackupToken
                    } else {
                        Remove-Item Env:\JAX_TEST_BACKUP_VAULT_TOKEN -ErrorAction SilentlyContinue
                    }
                }
            }
        }

        Context "Set-JaxVaultToken UX" {
            It "Prompts for method when VaultToken is empty (env vars must not suppress prompt)" {
                $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
                $tmpTokenPath = Join-Path $tmpRoot 'token'

                Mock Get-JaxVaultTokenPath { $tmpTokenPath }
                Mock Get-JaxVaultPluginConfig { @{ } }
                Mock Get-JaxRepoRoot { '/tmp/repo' }
                Mock Get-JaxConfig { @{ } }
                Mock Update-JaxVaultRepoConfig { @{ } }

                $script:promptCount = 0
                Mock Read-JaxPromptString {
                    $script:promptCount++
                    if ($script:promptCount -eq 1) { return 'https://env.example' } # vault address
                    if ($script:promptCount -eq 2) { return '.jax/testvaultenv/vault' } # tokenDir
                    return 'token'                                                     # auth method
                }
                Mock Read-Host { param($Prompt, $AsSecureString) (ConvertTo-SecureString 'abc' -AsPlainText -Force) }

                # Simulate "bad" env values - should not prevent method prompt.
                $oldAddr = $env:VAULT_ADDR
                $oldToken = $env:VAULT_TOKEN
                $env:VAULT_ADDR = 'https://env.example'
                $env:VAULT_TOKEN = 'envtoken'
                try {
                    Set-JaxVaultToken -VaultToken '' | Out-Null
                } finally {
                    $env:VAULT_ADDR = $oldAddr
                    $env:VAULT_TOKEN = $oldToken
                }

                Assert-MockCalled Read-JaxPromptString -Times 3
                (Test-Path $tmpTokenPath) | Should -Be $true
                (Get-Content -Path $tmpTokenPath -Raw).Trim() | Should -Be 'abc'
                if (-not $IsWindows) {
                    [IO.File]::GetUnixFileMode($tmpRoot) | Should -Be (
                        [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute
                    )
                    [IO.File]::GetUnixFileMode($tmpTokenPath) | Should -Be (
                        [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite
                    )
                }
            }

            It "Prefers config address over env VAULT_ADDR" {
                $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
                $tmpTokenPath = Join-Path $tmpRoot 'token'

                Mock Get-JaxVaultTokenPath { $tmpTokenPath }
                # Include tokenDir so this test never prompts for token directory (tests must be non-interactive).
                Mock Get-JaxVaultPluginConfig { @{ address = 'https://cfg.example'; tokenDir = '.jax/testvaultenv/vault'; policy = 'demo-policy'; tokenTtl = '8h' } }
                Mock Get-JaxRepoRoot { '/tmp/repo' }
                Mock Get-JaxConfig { @{ } }
                Mock Update-JaxVaultRepoConfig { @{ } }
                Mock Read-JaxPromptBool { return $false }

                $oldAddr = $env:VAULT_ADDR
                try {
                    $env:VAULT_ADDR = 'https://env.example'
                    Set-JaxVaultToken -Method token -VaultToken 'abc' | Out-Null
                    $env:VAULT_ADDR | Should -Be 'https://cfg.example'
                } finally {
                    $env:VAULT_ADDR = $oldAddr
                }
            }

            It "writes native standard input without appending a newline" {
                $pwshPath = (Get-Process -Id $PID).Path
                $inputText = 'github-secret-token'
                $script = @'
$value = [Console]::In.ReadToEnd()
[Console]::Out.Write([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($value)))
'@

                $result = Invoke-JaxNativeCommandWithStandardInput `
                    -FilePath $pwshPath `
                    -Arguments @('-NoLogo', '-NoProfile', '-Command', $script) `
                    -StandardInput $inputText

                $result.ExitCode | Should -Be 0
                $result.StdErr | Should -BeNullOrEmpty
                $result.StdOut | Should -Be ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($inputText)))
            }

            It "uses the configured GitHub auth mount without putting the GitHub token in process arguments" {
                $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
                $tmpTokenPath = Join-Path $tmpRoot 'token'

                Mock Get-JaxVaultTokenPath { $tmpTokenPath }
                Mock Get-JaxVaultPluginConfig {
                    @{
                        address   = 'https://vault.example'
                        authMount = 'github-example'
                        tokenDir  = '.jax/example/vault'
                        tokenTtl  = '8h'
                    }
                }
                Mock Get-JaxRepoRoot { '/tmp/repo' }
                Mock Get-JaxConfig { @{ } }
                Mock Update-JaxVaultRepoConfig { @{ } }
                Mock Read-JaxPromptBool { return $false }
                Mock Get-Command {
                    [pscustomobject]@{ Source = '/test/bin/vault' }
                } -ParameterFilter { $Name -eq 'vault' }
                Mock Invoke-JaxNativeCommandWithStandardInput {
                    param($FilePath, $Arguments, $StandardInput)
                    $script:vaultLoginFilePath = $FilePath
                    $script:vaultLoginArgs = @($Arguments)
                    $script:vaultLoginStandardInput = $StandardInput
                    return [pscustomobject]@{
                        ExitCode = 0
                        StdOut   = '{"auth":{"client_token":"vault-child-token"}}'
                        StdErr   = ''
                    }
                }

                $oldGitHubToken = $env:GITHUB_TOKEN
                try {
                    $env:GITHUB_TOKEN = 'github-secret-token'
                    Set-JaxVaultToken -Method github | Out-Null
                } finally {
                    $env:GITHUB_TOKEN = $oldGitHubToken
                }

                $script:vaultLoginFilePath | Should -Be '/test/bin/vault'
                ($script:vaultLoginArgs -join ' ') | Should -Be 'write -format=json auth/github-example/login token=-'
                ($script:vaultLoginArgs -join ' ') | Should -Not -Match 'github-secret-token'
                $script:vaultLoginStandardInput | Should -Be 'github-secret-token'
                (Get-Content -Path $tmpTokenPath -Raw).Trim() | Should -Be 'vault-child-token'
            }

            It "mints configured repository tokens as long-lived orphans" {
                $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
                $tmpTokenPath = Join-Path $tmpRoot 'token'

                Mock Get-JaxVaultTokenPath { $tmpTokenPath }
                Mock Get-JaxVaultPluginConfig {
                    @{
                        address  = 'https://vault.example'
                        tokenDir = '.jax/example/vault'
                        policy   = 'example-policy'
                        tokenTtl = '87600h'
                    }
                }
                Mock Get-JaxRepoRoot { '/tmp/repo' }
                Mock Get-JaxConfig { @{ } }
                Mock Update-JaxVaultRepoConfig { @{ } }
                Mock Read-JaxPromptBool { return $false }
                Mock Get-Command {
                    [pscustomobject]@{ Source = '/test/bin/vault' }
                } -ParameterFilter { $Name -eq 'vault' }
                Mock Invoke-JaxNativeCommandWithStandardInput {
                    param($FilePath, $Arguments, $StandardInput)
                    $script:vaultCreateFilePath = $FilePath
                    $script:vaultCreateArgs = @($Arguments)
                    $script:vaultCreateStandardInput = $StandardInput
                    return [pscustomobject]@{
                        ExitCode = 0
                        StdOut   = '{"auth":{"client_token":"vault-orphan-token","lease_duration":315360000}}'
                        StdErr   = ''
                    }
                }

                Set-JaxVaultToken -Method token -VaultToken 'vault-login-token' | Out-Null

                $script:vaultCreateFilePath | Should -Be '/test/bin/vault'
                ($script:vaultCreateArgs -join ' ') |
                    Should -Be 'write -format=json auth/token/create-orphan ttl=87600h policies=example-policy'
                $script:vaultCreateStandardInput | Should -BeNullOrEmpty
                (Get-Content -Path $tmpTokenPath -Raw).Trim() | Should -Be 'vault-orphan-token'
            }

            It "surfaces sanitized Vault GitHub login errors" {
                $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
                $tmpTokenPath = Join-Path $tmpRoot 'token'

                Mock Get-JaxVaultTokenPath { $tmpTokenPath }
                Mock Get-JaxVaultPluginConfig {
                    @{
                        address   = 'https://vault.example'
                        authMount = 'github-example'
                        tokenDir  = '.jax/example/vault'
                        tokenTtl  = '8h'
                    }
                }
                Mock Get-JaxRepoRoot { '/tmp/repo' }
                Mock Get-JaxConfig { @{ } }
                Mock Update-JaxVaultRepoConfig { @{ } }
                Mock Read-JaxPromptBool { return $false }
                Mock Get-Command {
                    [pscustomobject]@{ Source = '/test/bin/vault' }
                } -ParameterFilter { $Name -eq 'vault' }
                Mock Invoke-JaxNativeCommandWithStandardInput {
                    return [pscustomobject]@{
                        ExitCode = 2
                        StdOut   = ''
                        StdErr   = 'GitHub rejected github-secret-token'
                    }
                }

                $oldGitHubToken = $env:GITHUB_TOKEN
                try {
                    $env:GITHUB_TOKEN = 'github-secret-token'
                    {
                        Set-JaxVaultToken -Method github -ErrorAction Stop
                    } | Should -Throw '*Vault said: GitHub rejected*REDACTED*'
                } finally {
                    $env:GITHUB_TOKEN = $oldGitHubToken
                }
            }
        }

        Context "Get-JaxVaultToken precedence" {
            BeforeEach {
                # Bypass the Vault Agent Injector path — the test runner itself
                # may live inside a CI pod where /vault/secrets/token exists,
                # which would otherwise short-circuit every precedence test
                # because the injector source is priority 1.
                Mock Get-JaxVaultInjectorTokenPath { '/non-existent/vault-injector-token' }
            }

            It "Prefers saved token over env token by default" {
                $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
                $tmpTokenPath = Join-Path $tmpRoot 'token'
                New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
                Set-Content -Path $tmpTokenPath -Value 'filetoken' -Force

                Mock Get-JaxVaultTokenPath { $tmpTokenPath }
                Mock Get-JaxVaultPluginConfig { @{ } }

                $oldToken = $env:VAULT_TOKEN
                try {
                    $env:VAULT_TOKEN = 'envtoken'
                    (Get-JaxVaultToken) | Should -Be 'filetoken'
                } finally {
                    $env:VAULT_TOKEN = $oldToken
                }
            }

            It "Uses env token when allowed and no saved token exists" {
                $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
                $tmpTokenPath = Join-Path $tmpRoot 'token'

                Mock Get-JaxVaultTokenPath { $tmpTokenPath }
                Mock Get-JaxVaultPluginConfig { @{ allowEnvToken = $true } }

                $oldToken = $env:VAULT_TOKEN
                try {
                    $env:VAULT_TOKEN = 'envtoken'
                    (Get-JaxVaultToken) | Should -Be 'envtoken'
                } finally {
                    $env:VAULT_TOKEN = $oldToken
                }
            }

            It "Prefers env token over saved token when allowed" {
                $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
                $tmpTokenPath = Join-Path $tmpRoot 'token'
                New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
                Set-Content -Path $tmpTokenPath -Value 'filetoken' -Force

                Mock Get-JaxVaultTokenPath { $tmpTokenPath }
                Mock Get-JaxVaultPluginConfig { @{ allowEnvToken = $true } }

                $oldToken = $env:VAULT_TOKEN
                try {
                    $env:VAULT_TOKEN = 'envtoken'
                    (Get-JaxVaultToken) | Should -Be 'envtoken'
                } finally {
                    $env:VAULT_TOKEN = $oldToken
                }
            }

            It "Reads the Vault Agent Injector token when present" {
                $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
                $injectorPath = Join-Path $tmpRoot 'vault-injector-token'
                $savedPath    = Join-Path $tmpRoot 'token'
                New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
                Set-Content -Path $injectorPath -Value 'injector-token' -Force
                Set-Content -Path $savedPath    -Value 'filetoken'      -Force

                Mock Get-JaxVaultInjectorTokenPath { $injectorPath }
                Mock Get-JaxVaultTokenPath { $savedPath }
                Mock Get-JaxVaultPluginConfig { @{ allowEnvToken = $true } }

                $oldToken = $env:VAULT_TOKEN
                try {
                    $env:VAULT_TOKEN = 'envtoken'
                    (Get-JaxVaultToken) | Should -Be 'injector-token'
                } finally {
                    $env:VAULT_TOKEN = $oldToken
                }
            }
        }

        Context "Repo config persistence" {
            It "expands a minimal repo config only with Vault overrides" {
                $tmpRepo = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
                $tmpJaxDir = Join-Path $tmpRepo '.jax'
                New-Item -ItemType Directory -Path $tmpJaxDir -Force | Out-Null

                $cfgPath = Join-Path $tmpJaxDir 'jax.config.yml'
                Set-Content -Path $cfgPath -Value 'jax: {}' -Encoding ascii

                Update-JaxVaultRepoConfig -RepoRoot $tmpRepo `
                    -VaultAddress 'https://vault.example' `
                    -TokenDir '.jax/example/vault' `
                    -Policy 'example-policy' `
                    -TokenTtl '6h' | Out-Null

                $rawConfig = Get-Content -Path $cfgPath -Raw
                $rawConfig | Should -Not -Match '(?m)^\s{2}envRoot:'
                $rawConfig | Should -Not -Match '(?m)^\s{2}autocomplete:'

                $cfg = Read-JaxYaml -Path $cfgPath
                $cfg.jax.plugins.enabled | Should -Contain 'machine'
                $cfg.jax.plugins.enabled | Should -Contain 'bob'
                $cfg.jax.plugins.enabled | Should -Contain 'vault'
                $cfg.jax.plugins.disabled | Should -Not -Contain 'vault'
                $cfg.jax.plugins.config.vault.address | Should -Be 'https://vault.example'

                Remove-Item -Path $tmpRepo -Recurse -Force
            }

            It "Writes vault address + tokenDir into .jax/jax.config.yml during vault set when missing" {
                $tmpRepo = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
                $tmpJaxDir = Join-Path $tmpRepo '.jax'
                New-Item -ItemType Directory -Path $tmpJaxDir -Force | Out-Null

                $cfgPath = Join-Path $tmpJaxDir 'jax.config.yml'
                @"
jax:
  plugins:
    config:
      vault:
        enabled: false
"@ | Set-Content -Path $cfgPath -Encoding ascii

                Mock Get-JaxRepoRoot { $tmpRepo }
                $tmpTokenRoot = Join-Path $tmpRepo 'token-store'
                $tmpTokenPath = Join-Path $tmpTokenRoot 'token'
                New-Item -ItemType Directory -Path $tmpTokenRoot -Force | Out-Null
                Mock Get-JaxVaultTokenPath { $tmpTokenPath }
                Mock Read-JaxPromptString {
                    param($Prompt, $Default)
                    if ($Prompt -eq 'Vault address') { return 'http://127.0.0.1:8200' }
                    if ($Prompt -like 'Token directory (relative to HOME or absolute*') { return '.jax/testvaultenv/vault' }
                    return $Default
                }

                # Avoid interactive token prompt (token path is mocked to stay inside $tmpRepo)
                Set-JaxVaultToken -Method token -VaultToken 'abc' | Out-Null

                $cfg = Read-JaxYaml -Path $cfgPath
                $cfg.jax.plugins.config.vault.address | Should -Be 'http://127.0.0.1:8200'
                $cfg.jax.plugins.config.vault.tokenDir | Should -Be '.jax/testvaultenv/vault'
                $cfg.jax.plugins.config.vault.Contains('policy') | Should -BeFalse
                $cfg.jax.plugins.config.vault.Contains('tokenTtl') | Should -BeFalse
                $cfg.jax.plugins.config.vault.enabled | Should -Be $true

                (Test-Path $tmpTokenPath) | Should -Be $true
                (Get-Content -Path $tmpTokenPath -Raw).Trim() | Should -Be 'abc'
            }
        }

        Context "Get-JaxVaultTokenPath" {
            It "Defaults to ~/.jax/vault/token" {
                Mock Get-JaxRepoRoot { '/tmp/repo' }
                Mock Get-JaxConfig { @{ } }
                Mock Get-JaxVaultPluginConfig { @{ } }

                $expected = Join-Path $HOME (Join-Path '.jax' (Join-Path 'vault' 'token'))
                (Get-JaxVaultTokenPath) | Should -Be $expected
            }

            It "Uses config tokenStoreKey when set (e.g. testvaultenv)" {
                Mock Get-JaxRepoRoot { '/tmp/repo' }
                Mock Get-JaxConfig { @{ } }
                Mock Get-JaxVaultPluginConfig { @{ tokenStoreKey = 'testvaultenv' } }

                $expected = Join-Path $HOME (Join-Path '.jax' (Join-Path 'testvaultenv' (Join-Path 'vault' 'token')))
                (Get-JaxVaultTokenPath) | Should -Be $expected
            }

            It "Uses config tokenDir when set (relative path under HOME)" {
                Mock Get-JaxRepoRoot { '/tmp/repo' }
                Mock Get-JaxConfig { @{ } }
                Mock Get-JaxVaultPluginConfig { @{ tokenDir = '.jax/testvaultenv/vault' } }

                $expected = Join-Path $HOME (Join-Path '.jax' (Join-Path 'testvaultenv' (Join-Path 'vault' 'token')))
                (Get-JaxVaultTokenPath) | Should -Be $expected
            }
        }
    }
}

Describe "Jax Vault CLI repository targeting" {
    It "uses -C to select the repository-specific Vault token store" {
        $targetRepo = Join-Path $TestDrive 'target-repo'
        $callerRepo = Join-Path $TestDrive 'caller-repo'
        New-Item -ItemType Directory -Path (Join-Path $targetRepo '.jax') -Force | Out-Null
        New-Item -ItemType Directory -Path $callerRepo -Force | Out-Null
        & git -C $targetRepo init --quiet
        & git -C $callerRepo init --quiet
        @'
jax:
  plugins:
    config:
      vault:
        address: https://vault.example
        tokenDir: .jax/target-repo/vault
'@ | Set-Content -LiteralPath (Join-Path $targetRepo '.jax/jax.config.yml') -Encoding ascii

        $previousRepoRoot = $env:JAX_REPO_ROOT
        Remove-Item Env:JAX_REPO_ROOT -ErrorAction SilentlyContinue
        $launcher = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../jax.ps1')).Path
        Push-Location $callerRepo
        try {
            $output = & $launcher -C $targetRepo vault status -q 6>&1 | Out-String
        } finally {
            Pop-Location
            if ($null -eq $previousRepoRoot) {
                Remove-Item Env:JAX_REPO_ROOT -ErrorAction SilentlyContinue
            } else {
                $env:JAX_REPO_ROOT = $previousRepoRoot
            }
        }

        $expectedTokenPath = Join-Path $HOME '.jax/target-repo/vault/token'
        $output | Should -Match ([regex]::Escape("Token path: $expectedTokenPath"))
        $output | Should -Not -Match ([regex]::Escape((Join-Path $HOME '.jax/vault/token')))
    }
}
