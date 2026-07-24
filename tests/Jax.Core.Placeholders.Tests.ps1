$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Expand-JaxPlaceholders' {
    It 'expands simple substitutions' {
        Import-Module (Join-Path $PSScriptRoot '../MustachePlaceholders/MustachePlaceholders.psm1') -Force
        $config = @{
            root = @{
                value = 'hello'
            }
            message = '{{ root.value }}'
        }

        $expanded = Expand-JaxPlaceholders -Config $config
        $expanded.message | Should -Be 'hello'
    }

    It 'includes source file and line when a variable is missing (best effort)' {
        Import-Module (Join-Path $PSScriptRoot '../MustachePlaceholders/MustachePlaceholders.psm1') -Force

        $tempFile = Join-Path $TestDrive 'config.yml'
        @(
            "module:"
            "  docker:"
            "    images:"
            "      directus:"
            "        version:"
            "          base: '{{ module.docker.version.static.directus.baseSIMULATEDERROR }}'"
        ) | Set-Content -LiteralPath $tempFile -Encoding utf8

        $config = @{
            module = @{
                docker = @{
                    images = @{
                        directus = @{
                            version = @{
                                base = '{{ module.docker.version.static.directus.baseSIMULATEDERROR }}'
                            }
                        }
                    }
                }
            }
        }

        {
            Expand-JaxPlaceholders -Config $config -SourcePaths @($tempFile) | Out-Null
        } | Should -Throw

        try {
            Expand-JaxPlaceholders -Config $config -SourcePaths @($tempFile) | Out-Null
        } catch {
            $escapedTempFile = [regex]::Escape($tempFile)
            $_.Exception.Message | Should -Match "Can't substitute value of 'module\.docker\.version\.static\.directus\.baseSIMULATEDERROR'"
            $_.Exception.Message | Should -Match "\.module\.docker\.images\.directus\.version\.base"
            $_.Exception.Message | Should -Match "Source: "
            $_.Exception.Message | Should -Match $escapedTempFile
            $_.Exception.Message | Should -Match ":[0-9]+"
        }
    }
}

Describe 'Get-JaxFlowConfig' {
    It 'expands variables by default' {
        InModuleScope Jax.Core {
            Mock -CommandName Read-JaxYaml -MockWith {
                return @{
                    name = 'world'
                    message = 'Hello {{ name }}'
                }
            }

            $result = Get-JaxFlowConfig -Path 'ignored'
            $result.message | Should -Be 'Hello world'
            Assert-MockCalled -CommandName Read-JaxYaml -Times 1
        }
    }

    It 'merges layered flow configs in order' {
        InModuleScope Jax.Core {
            Mock -CommandName Read-JaxYaml -MockWith {
                param($Path)
                if ($Path -eq 'base') {
                    return @{
                        name = 'base'
                        settings = @{
                            alpha = 1
                        }
                    }
                }
                return @{
                    name = 'override'
                    settings = @{
                        beta = 2
                    }
                }
            }

            $result = Get-JaxFlowConfig -Paths @('base', 'override') -ExpandVariables:$false
            $result.name | Should -Be 'override'
            $result.settings.alpha | Should -Be 1
            $result.settings.beta | Should -Be 2
            Assert-MockCalled -CommandName Read-JaxYaml -Times 2
        }
    }
}
