$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Invoke-JaxRunEntity' {
    It 'dispatches to script runner' {
        InModuleScope Jax.Core {
            Mock -CommandName Invoke-JaxScriptRunner

            $entity = @{
                Runner = 'script'
                Script = 'do.ps1'
            }

            Invoke-JaxRunEntity -Entity $entity -Context @{ DryRun = $true } | Out-Null

            Assert-MockCalled -CommandName Invoke-JaxScriptRunner -Times 1
        }
    }

    It 'dispatches to psake runner' {
        InModuleScope Jax.Core {
            Mock -CommandName Invoke-JaxPsakeRunner

            $entity = @{
                Runner    = 'psake'
                PsakeFile = 'psakefile.ps1'
                Tasks     = @('Build')
            }

            Invoke-JaxRunEntity -Entity $entity -Context @{ DryRun = $true } | Out-Null

            Assert-MockCalled -CommandName Invoke-JaxPsakeRunner -Times 1
        }
    }

    It 'uses container runner when container is set' {
        InModuleScope Jax.Core {
            Mock -CommandName Invoke-JaxContainerRunner

            $entity = @{
                Runner    = 'psake'
                PsakeFile = 'psakefile.ps1'
                Tasks     = @('Build')
                Container = @{ image = 'demo/image:1.0' }
            }

            Invoke-JaxRunEntity -Entity $entity -Context @{ DryRun = $true } | Out-Null

            Assert-MockCalled -CommandName Invoke-JaxContainerRunner -Times 1
        }
    }

    It 'uses container runner when -Docker is set' {
        InModuleScope Jax.Core {
            Mock -CommandName Invoke-JaxContainerRunner

            $entity = @{
                Runner    = 'psake'
                PsakeFile = 'psakefile.ps1'
                Tasks     = @('Build')
            }

            Invoke-JaxRunEntity -Entity $entity -Docker -ContainerImage 'demo/image:1.0' | Out-Null

            Assert-MockCalled -CommandName Invoke-JaxContainerRunner -Times 1
        }
    }

    It 'maps legacy Type to runner' {
        InModuleScope Jax.Core {
            Mock -CommandName Invoke-JaxPsakeRunner

            $entity = @{
                Type      = 'NativePsakeTask'
                PsakeFile = 'psakefile.ps1'
                Tasks     = @('Build')
            }

            Invoke-JaxRunEntity -Entity $entity -Context @{ DryRun = $true } | Out-Null

            Assert-MockCalled -CommandName Invoke-JaxPsakeRunner -Times 1
        }
    }

    It 'dispatches scenario runner for nested entities' {
        InModuleScope Jax.Core {
            Mock -CommandName Invoke-JaxRunEntity

            $entity = @{
                Runner   = 'scenario'
                Entities = @(
                    @{ Runner = 'script'; Script = 'one.ps1' },
                    @{ Runner = 'psake'; PsakeFile = 'psakefile.ps1'; Tasks = @('Build') }
                )
            }

            $handler = Get-JaxRunner -Name 'scenario'
            & $handler $entity @{ DryRun = $true; SkipPlugins = $true } | Out-Null

            Assert-MockCalled -CommandName Invoke-JaxRunEntity -Times 2
        }
    }
}

Describe 'Invoke-JaxScriptRunner' {
    It 'does not display Vault-resolved arguments in a dry run' {
        InModuleScope Jax.Core {
            $repoRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            $secretValue = 'vault-direct-script-value'
            $entity = @{
                Runner = 'script'
                Script = (Join-Path $repoRoot 'scripts/run.ps1')
                Args   = @{ deployValue = $secretValue }
            }

            $command = Invoke-JaxScriptRunner -Entity $entity -Context @{
                RepoRoot             = $repoRoot
                DryRun               = $true
                VaultSecretsResolved = $true
            }

            $command | Should -Match '<arguments redacted>'
            $command | Should -Not -Match ([regex]::Escape($secretValue))
        }
    }
}

Describe 'Invoke-JaxContainerRunner' {
    BeforeAll {
        $script:removeDockerTestStub = -not [bool](Get-Command docker -ErrorAction SilentlyContinue)
        if ($script:removeDockerTestStub) {
            function global:docker {
                $global:LASTEXITCODE = 1
                return 'docker test stub'
            }
        }
    }

    AfterAll {
        if ($script:removeDockerTestStub) {
            Remove-Item Function:\global:docker -ErrorAction SilentlyContinue
        }
    }

    It 'keeps script arguments as literal Docker arguments' {
        InModuleScope Jax.Core {
            $repoRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            $entity = @{
                Runner    = 'container'
                InnerRunner = 'script'
                Script    = (Join-Path $repoRoot 'scripts/run.ps1')
                Args      = @{ Value = 'hello; Write-Error injected' }
                Container = @{
                    image = 'example/image:1.0'
                    env   = @('DEMO_SECRET=not-printed')
                }
            }

            $command = Invoke-JaxContainerRunner -Entity $entity -Context @{
                RepoRoot = $repoRoot
                DryRun   = $true
            }

            $command | Should -Match ([regex]::Escape("'hello; Write-Error injected'"))
            $command | Should -Match 'DEMO_SECRET=<redacted>'
            $command | Should -Not -Match 'not-printed'
        }
    }

    It 'escapes quotes in psake task names in the in-container command' {
        InModuleScope Jax.Core {
            $repoRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            $entity = @{
                Runner      = 'container'
                InnerRunner = 'psake'
                PsakeFile   = (Join-Path $repoRoot 'psakefile.ps1')
                Tasks       = @("Build'Test")
                Container   = @{ image = 'example/image:1.0' }
            }

            $command = Invoke-JaxContainerRunner -Entity $entity -Context @{
                RepoRoot = $repoRoot
                DryRun   = $true
            }

            $command | Should -Match ([regex]::Escape("Build''''Test"))
        }
    }

    It 'does not display Vault-resolved container values' {
        InModuleScope Jax.Core {
            $repoRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            $secretValue = 'vault-value-with-unexpected-name'
            $entity = @{
                Runner      = 'container'
                InnerRunner = 'script'
                Script      = (Join-Path $repoRoot 'scripts/run.ps1')
                Args        = @{ deployValue = $secretValue }
                Container   = @{
                    image  = "example/image:$secretValue"
                    mounts = @("$secretValue`:/private")
                }
            }

            $command = Invoke-JaxContainerRunner -Entity $entity -Context @{
                RepoRoot            = $repoRoot
                DryRun              = $true
                VaultSecretsResolved = $true
            }

            $command | Should -Match '<arguments redacted>'
            $command | Should -Match '<image redacted>'
            $command | Should -Not -Match ([regex]::Escape($secretValue))
        }
    }

    It 'does not print a Vault-resolved image during execution or debug logging' {
        InModuleScope Jax.Core {
            $repoRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            $secretValue = 'vault-image-value'
            $entity = @{
                Runner      = 'container'
                InnerRunner = 'script'
                Script      = (Join-Path $repoRoot 'scripts/run.ps1')
                Container   = @{ image = "example/image:$secretValue" }
            }

            $script:capturedRunnerOutput = @()
            Mock -CommandName Write-Debug -MockWith {
                param($Message)
                $script:capturedRunnerOutput += [string]$Message
            }
            Mock -CommandName Write-Host -MockWith {
                $script:capturedRunnerOutput += [string]($args -join ' ')
            }
            Mock -CommandName docker

            Invoke-JaxContainerRunner -Entity $entity -Context @{
                RepoRoot             = $repoRoot
                VaultSecretsResolved = $true
            } | Out-Null

            ($script:capturedRunnerOutput -join "`n") | Should -Match '<redacted>'
            ($script:capturedRunnerOutput -join "`n") | Should -Not -Match ([regex]::Escape($secretValue))
        }
    }
}

Describe 'Invoke-JaxPsakeRunner' {
    It 'merges run config, psake properties, and entity args' {
        InModuleScope Jax.Core {
            Mock -CommandName Initialize-JaxPsakeProvider
            Mock -CommandName Write-JaxLogFile -MockWith { return '/tmp/psake-params.json' }

            $script:capturedProperties = $null
            Mock -CommandName Invoke-psake -MockWith {
                param($buildFile, $taskList, $properties)
                $script:capturedProperties = $properties
                return $true
            }

            $repoRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            $runScripts = Join-Path $repoRoot 'scripts'

            $entity = @{
                Runner    = 'psake'
                PsakeFile = 'psakefile.ps1'
                Tasks     = @('Info')
                Args      = @{
                    env   = @{ git = @{ root = 'args-root' } }
                    extra = 'from-args'
                }
            }

            $context = @{
                RepoRoot = $repoRoot
                RunConfig = @{
                    env = @{
                        git = @{ root = 'run-root' }
                        build = @{ scripts = @{ folder = $runScripts } }
                    }
                    sample = 'run'
                }
                PsakeProperties = @{
                    env = @{ git = @{ root = 'psake-root' } }
                    sample = 'psake'
                }
            }

            Invoke-JaxPsakeRunner -Entity $entity -Context $context | Out-Null

            $script:capturedProperties['env']['git']['root'] | Should -Be 'args-root'
            $script:capturedProperties['env']['build']['scripts']['folder'] | Should -Be $runScripts
            $script:capturedProperties['sample'] | Should -Be 'psake'
            $script:capturedProperties['extra'] | Should -Be 'from-args'
        }
    }

    It 'avoids psake $module init collision but still restores properties.module for tasks' {
        InModuleScope Jax.Core {
            Mock -CommandName Initialize-JaxPsakeProvider
            Mock -CommandName Write-JaxLogFile -MockWith { return '/tmp/psake-params.json' }

            $script:capturedProperties = $null
            $script:capturedInitialization = $null
            Mock -CommandName Invoke-psake -MockWith {
                param($buildFile, $taskList, $properties, $initialization)
                $script:capturedProperties = $properties
                $script:capturedInitialization = $initialization
                return $true
            }

            $entity = @{
                Runner    = 'psake'
                PsakeFile = 'psakefile.ps1'
                Tasks     = @('Info')
            }
            $context = @{
                RepoRoot = (Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString()))
                RunConfig = @{
                    module = @{
                        root = 'some-root'
                    }
                }
            }

            Invoke-JaxPsakeRunner -Entity $entity -Context $context | Out-Null

            $script:capturedProperties.ContainsKey('module') | Should -Be $false
            $script:capturedProperties.ContainsKey('__jax_module') | Should -Be $true
            $script:capturedInitialization | Should -Not -BeNullOrEmpty

            $properties = $script:capturedProperties
            & $script:capturedInitialization
            $script:capturedProperties.ContainsKey('module') | Should -Be $true
            $script:capturedProperties['module']['root'] | Should -Be 'some-root'
        }
    }

    It 'does not persist Vault-resolved properties under non-obvious keys' {
        InModuleScope Jax.Core {
            Mock -CommandName Initialize-JaxPsakeProvider
            $script:capturedLogContent = $null
            Mock -CommandName Write-JaxLogFile -MockWith {
                param($Content)
                $script:capturedLogContent = $Content
                return '/tmp/psake-params.json'
            }
            Mock -CommandName Invoke-psake -MockWith { return $true }

            $secretValue = 'vault-resolved-deploy-value'
            $entity = @{
                Runner    = 'psake'
                PsakeFile = 'psakefile.ps1'
                Tasks     = @('Deploy')
                Args      = @{ deployValue = $secretValue }
            }
            $context = @{
                RepoRoot             = (Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString()))
                RunConfig            = @{ signingCredential = $secretValue }
                VaultSecretsResolved = $true
            }

            Invoke-JaxPsakeRunner -Entity $entity -Context $context | Out-Null

            $script:capturedLogContent | Should -Match 'Vault-resolved properties'
            $script:capturedLogContent | Should -Not -Match ([regex]::Escape($secretValue))
            $script:capturedLogContent | Should -Not -Match 'deployValue|signingCredential'
        }
    }
}
