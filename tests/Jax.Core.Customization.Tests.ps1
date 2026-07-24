$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Jax repo config wizard' {
    It 'writes repo config from wizard input' {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempRoot | Out-Null

        $queue = [System.Collections.Queue]::new()
        $queue.Enqueue('y')
        $queue.Enqueue('custom-env')
        $queue.Enqueue('')
        $queue.Enqueue('')
        $queue.Enqueue('')
        $queue.Enqueue('')
        $queue.Enqueue('')
        $queue.Enqueue('')
        $queue.Enqueue('')
        $queue.Enqueue('')
        $queue.Enqueue('')
        $queue.Enqueue('')
        $queue.Enqueue('')

        Invoke-JaxCustomizationWizard -RepoRoot $tempRoot -InputQueue $queue

        $repoConfigPath = Join-Path $tempRoot '.jax/jax.config.yml'
        Test-Path -Path $repoConfigPath -PathType Leaf | Should -Be $true

        $repoConfig = Read-JaxYaml -Path $repoConfigPath
        $repoConfig.jax.envRoot | Should -Be 'custom-env'

        Remove-Item -Path $tempRoot -Recurse -Force
    }

    It 'parses list and map prompt inputs' {
        InModuleScope Jax.Core {
            $queue = [System.Collections.Queue]::new()
            $queue.Enqueue('a, b, c')
            $list = Read-JaxPromptList -Prompt 'list' -Default @() -InputQueue $queue
            $list | Should -Be @('a', 'b', 'c')

            $queue = [System.Collections.Queue]::new()
            $queue.Enqueue('key=value, foo=bar')
            $map = Read-JaxPromptMap -Prompt 'map' -Default @{} -InputQueue $queue
            $map['key'] | Should -Be 'value'
            $map['foo'] | Should -Be 'bar'
        }
    }
}
