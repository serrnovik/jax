BeforeAll {
    $coreModulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
    Import-Module $coreModulePath -Force
}

Describe 'Select-JaxRunEntities' {
    It 'filters by -only using exact match (no prefix)' {
        $entities = @(
            @{ Key = 'build' },
            @{ Key = 'test' },
            @{ Key = 'deploy' }
        )

        $result = @(Select-JaxRunEntities -Entities $entities -Only 'test')
        $result.Count | Should -Be 1
        $result[0].Key | Should -Be 'test'

        $noPrefix = @(Select-JaxRunEntities -Entities $entities -Only 'te')
        $noPrefix.Count | Should -Be 0
    }

    It 'slices by -from and -to' {
        $entities = @(
            @{ Key = 'build' },
            @{ Key = 'test' },
            @{ Key = 'deploy' }
        )

        $result = @(Select-JaxRunEntities -Entities $entities -From 'test' -To 'deploy')
        $result.Count | Should -Be 2
        $result[0].Key | Should -Be 'test'
        $result[1].Key | Should -Be 'deploy'
    }

    It 'matches aliases and ignores slashes/spaces' {
        $entities = @(
            @{ Key = 'client/build'; Aliases = @('quick build') },
            @{ Key = 'deploy' }
        )

        $aliasMatch = @(Select-JaxRunEntities -Entities $entities -Only 'quick build')
        $aliasMatch.Count | Should -Be 1
        $aliasMatch[0].Key | Should -Be 'client/build'

        $normalizedMatch = @(Select-JaxRunEntities -Entities $entities -Only 'client build')
        $normalizedMatch.Count | Should -Be 1
        $normalizedMatch[0].Key | Should -Be 'client/build'
    }

    It 'prefers matching entity Key over matching entity Tasks (prevents double-run)' {
        $entities = @(
            # Scenario step-like entity: key does not match, but Tasks contains the target string
            @{ Key = 'docker'; Tasks = @('BumpSomething', 'BuildSampleAppImage') },
            # Actual entity key we want to run
            @{ Key = 'BuildSampleAppImage' }
        )

        $result = @(Select-JaxRunEntities -Entities $entities -Only 'BuildSampleAppImage')
        $result.Count | Should -Be 1
        $result[0].Key | Should -Be 'BuildSampleAppImage'
    }
}

Describe 'Resolve-JaxRunPlan' {
    It 'combines build and scenario entities with selection' {
        $build = @(
            @{ Key = 'build' },
            @{ Key = 'package' }
        )
        $scenarios = @(
            @{ Key = 'deploy' },
            @{ Key = 'notify' }
        )

        $result = @(Resolve-JaxRunPlan -BuildEntities $build -ScenarioEntities $scenarios -From 'package')
        $result.Count | Should -Be 3
        $result[0].Key | Should -Be 'package'
        $result[2].Key | Should -Be 'notify'
    }

    It 'respects -noBuild and -buildChainOnly' {
        $build = @(
            @{ Key = 'build' }
        )
        $scenarios = @(
            @{ Key = 'deploy' }
        )

        $noBuild = @(Resolve-JaxRunPlan -BuildEntities $build -ScenarioEntities $scenarios -NoBuild)
        $noBuild.Count | Should -Be 1
        $noBuild[0].Key | Should -Be 'deploy'

        $buildOnly = @(Resolve-JaxRunPlan -BuildEntities $build -ScenarioEntities $scenarios -BuildChainOnly)
        $buildOnly.Count | Should -Be 1
        $buildOnly[0].Key | Should -Be 'build'
    }

    It 'builds an ad-hoc scenario from comma-separated -only selectors' {
        $scenarios = @(
            @{ Key = 'build' },
            @{ Key = 'test' },
            @{ Key = 'deploy' }
        )

        $result = @(Resolve-JaxRunPlan -ScenarioEntities $scenarios -Only 'build,deploy')

        $result.Count | Should -Be 1
        $result[0].Runner | Should -Be 'scenario'
        $children = @($result[0].Entities)
        $children.Count | Should -Be 2
        $children[0].Key | Should -Be 'build'
        $children[1].Key | Should -Be 'deploy'
    }

    It 'builds an ad-hoc scenario from PowerShell array -only selectors' {
        $scenarios = @(
            @{ Key = 'build' },
            @{ Key = 'test' },
            @{ Key = 'deploy' }
        )

        $result = @(Resolve-JaxRunPlan -ScenarioEntities $scenarios -Only @('build', 'test', 'deploy'))

        $result.Count | Should -Be 1
        $children = @($result[0].Entities)
        $children.Count | Should -Be 3
        $children[0].Key | Should -Be 'build'
        $children[1].Key | Should -Be 'test'
        $children[2].Key | Should -Be 'deploy'
    }

    It 'slices inside an ad-hoc scenario when -from/-to are provided' {
        $scenarios = @(
            @{ Key = 'build' },
            @{ Key = 'test' },
            @{ Key = 'deploy' }
        )

        $result = @(Resolve-JaxRunPlan -ScenarioEntities $scenarios -Only 'build,test,deploy' -From 'test')

        $result.Count | Should -Be 1
        $children = @($result[0].Entities)
        $children.Count | Should -Be 2
        $children[0].Key | Should -Be 'test'
        $children[1].Key | Should -Be 'deploy'
    }

    It 'does not run a partial ad-hoc scenario when a selector is missing' {
        $scenarios = @(
            @{ Key = 'build' },
            @{ Key = 'deploy' }
        )

        { Resolve-JaxRunPlan -ScenarioEntities $scenarios -Only 'build,test,deploy' } | Should -Throw "*test*"
    }
}

Describe 'Resolve-JaxSelectedEnvironment' {
    It 'selects by env and client' {
        $envs = @(
            [pscustomobject]@{ Name = 'acme/dev' },
            [pscustomobject]@{ Name = 'acme/prod' }
        )

        $selected = Resolve-JaxSelectedEnvironment -Environments $envs -Env 'dev' -Client 'acme'
        $selected.Name | Should -Be 'acme/dev'
    }

    It 'prefers exact match over prefix match' {
        $envs = @(
            [pscustomobject]@{ Name = 'example-first-play' },
            [pscustomobject]@{ Name = 'example' }
        )

        $selected = Resolve-JaxSelectedEnvironment -Environments $envs -Env 'example'
        $selected.Name | Should -Be 'example'
    }

    It 'falls back to prefix match when no exact match exists' {
        $envs = @(
            [pscustomobject]@{ Name = 'example-first-play' },
            [pscustomobject]@{ Name = 'other' }
        )

        $selected = Resolve-JaxSelectedEnvironment -Environments $envs -Env 'example'
        $selected.Name | Should -Be 'example-first-play'
    }
}
