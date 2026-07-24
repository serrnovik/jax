$modulePath = Join-Path $PSScriptRoot '../core/Jax.Core.psm1'
Import-Module $modulePath -Force

Describe 'Get-JaxRepoRoot' {
    It 'uses JAX_REPO_ROOT when set' {
        InModuleScope Jax.Core {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $tempRoot | Out-Null

            $env:JAX_REPO_ROOT = $tempRoot
            $resolved = Get-JaxRepoRoot
            $resolved | Should -Be (Resolve-Path $tempRoot).Path

            Remove-Item -Path $tempRoot -Recurse -Force
            $env:JAX_REPO_ROOT = $null
        }
    }

    It 'uses an exact explicit path even when the environment points elsewhere' {
        InModuleScope Jax.Core {
            $envRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            $exactRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $envRoot | Out-Null
            New-Item -ItemType Directory -Path $exactRoot | Out-Null

            try {
                $env:JAX_REPO_ROOT = $envRoot
                Get-JaxRepoRoot -StartPath $exactRoot -Exact | Should -Be (Resolve-Path $exactRoot).Path
            } finally {
                $env:JAX_REPO_ROOT = $null
                Remove-Item -Path $envRoot, $exactRoot -Recurse -Force
            }
        }
    }

    It 'walks up to .git directory' {
        InModuleScope Jax.Core {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            $subDir = Join-Path $tempRoot 'src/module'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $tempRoot '.git') -Force | Out-Null

            $resolved = Get-JaxRepoRoot -StartPath $subDir
            $resolved | Should -Be (Resolve-Path $tempRoot).Path

            Remove-Item -Path $tempRoot -Recurse -Force
        }
    }

    It 'treats .git file as repo root marker (submodule)' {
        InModuleScope Jax.Core {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
            $subDir = Join-Path $tempRoot 'src/module'
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            Set-Content -Path (Join-Path $tempRoot '.git') -Value 'gitdir: ../.git/modules/sample' -Encoding ascii

            $resolved = Get-JaxRepoRoot -StartPath $subDir
            $resolved | Should -Be (Resolve-Path $tempRoot).Path

            Remove-Item -Path $tempRoot -Recurse -Force
        }
    }
}
