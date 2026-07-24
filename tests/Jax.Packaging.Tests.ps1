Describe 'Standalone Jax packaging' {
    BeforeAll {
        $script:sourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
        $script:testRoot = Join-Path ([IO.Path]::GetTempPath()) ('jax-packaging-' + [guid]::NewGuid().ToString('N'))
        $script:installRoot = Join-Path $script:testRoot 'installed'
        $script:profilePath = Join-Path $script:testRoot 'profile.ps1'
        $script:consumerRoot = Join-Path $script:testRoot 'consumer'
        New-Item -ItemType Directory -Path $script:consumerRoot -Force | Out-Null
        & git -C $script:consumerRoot init --quiet
        if ($LASTEXITCODE -ne 0) { throw 'Failed to initialize the test consumer repository.' }
    }

    AfterAll {
        Get-Module Jax, Jax.Autocomplete | Remove-Module -Force -ErrorAction SilentlyContinue
        Get-Module Jax.Core | Where-Object Path -Like "$script:installRoot*" | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:sourceRoot 'core/Jax.Core.psm1') -Global -Force
        if (Test-Path -LiteralPath $script:testRoot) {
            Remove-Item -LiteralPath $script:testRoot -Recurse -Force
        }
    }

    It 'installs an allowlisted runtime and updates the profile idempotently' {
        $installer = Join-Path $script:sourceRoot 'Install-Jax.ps1'
        $installOutput = & $installer -InstallRoot $script:installRoot -ProfilePath $script:profilePath `
            -Shell powershell *>&1 | Out-String
        & $installer -InstallRoot $script:installRoot -ProfilePath $script:profilePath -Shell powershell

        $LASTEXITCODE | Should -BeIn @(0, $null)
        Test-Path -LiteralPath (Join-Path $script:installRoot 'Jax.psd1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:installRoot 'INSTALLATION.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:installRoot 'core/Jax.Core.psm1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:installRoot 'psake/src/psake.psm1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:installRoot 'skills/jax/SKILL.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:installRoot 'shell/jax.zsh') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:installRoot 'LICENSE') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:installRoot 'tests') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:installRoot 'plugins/tests') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:installRoot 'psake/tests') | Should -BeFalse

        $profileContent = Get-Content -LiteralPath $script:profilePath -Raw
        ([regex]::Matches($profileContent, '# >>> jax CLI >>>')).Count | Should -Be 1
        $installOutput | Should -Match "Import-Module '.*Jax\.psd1' -Global"
        $profileContent | Should -Match ([regex]::Escape((Join-Path $script:installRoot 'Jax.psd1')))
        $profileContent | Should -Not -Match 'Get-Module -ListAvailable Jax'
        $profileContent | Should -Match 'Remove-Module -Force'
        $profileContent | Should -Not -Match 'Register-JaxCompletion'
    }

    It 'builds an allowlisted PowerShell Gallery package' {
        $packageRoot = Join-Path $script:testRoot 'gallery-package'

        & (Join-Path $script:sourceRoot 'Build-JaxPackage.ps1') -OutputPath $packageRoot

        Test-Path -LiteralPath (Join-Path $packageRoot 'Jax.psd1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $packageRoot 'core') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $packageRoot 'shell/Jax.ShellLauncher.ps1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $packageRoot 'LICENSE') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $packageRoot 'README.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $packageRoot 'INSTALLATION.json') | Should -BeTrue
        $packageMetadata = Get-Content -LiteralPath (Join-Path $packageRoot 'INSTALLATION.json') -Raw |
            ConvertFrom-Json
        $packageMetadata.Version | Should -Be (Get-Content -LiteralPath (Join-Path $script:sourceRoot 'VERSION') -Raw).Trim()
        $packageMetadata.SourceCommit | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath (Join-Path $packageRoot 'tests') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $packageRoot 'docs') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $packageRoot 'Install-Jax.ps1') | Should -BeFalse
        { Test-ModuleManifest -Path (Join-Path $packageRoot 'Jax.psd1') -ErrorAction Stop } |
            Should -Not -Throw
    }

    It 'registers idempotent PowerShell profile integration' {
        Import-Module (Join-Path $script:installRoot 'Jax.psd1') -Force
        $powerShellProfile = Join-Path $script:testRoot 'profiles/profile.ps1'

        Install-JaxShellIntegration -Shell powershell -PowerShellProfilePath $powerShellProfile
        Install-JaxShellIntegration -Shell powershell -PowerShellProfilePath $powerShellProfile

        $profileContent = Get-Content -LiteralPath $powerShellProfile -Raw
        ([regex]::Matches($profileContent, '# >>> jax CLI >>>')).Count | Should -Be 1
        $profileContent | Should -Match 'Get-Module -ListAvailable Jax'
        $profileContent | Should -Match "Join-Path [`$]HOME '.jax/module/Jax\.psd1'"
        $profileContent | Should -Match 'Remove-Module -Force'
        $profileContent | Should -Match 'Import-Module [`$]jaxProfileModulePath -Global'
    }

    It 'registers idempotent zsh and bash shell integration' -Skip:($IsWindows) {
        Import-Module (Join-Path $script:installRoot 'Jax.psd1') -Force
        $shellRoot = Join-Path $script:testRoot 'shell-integration'
        $zshProfile = Join-Path $script:testRoot 'profiles/.zshrc'
        $bashProfile = Join-Path $script:testRoot 'profiles/.bashrc'

        Install-JaxShellIntegration -Shell zsh, bash -InstallRoot $shellRoot `
            -ZshProfilePath $zshProfile -BashProfilePath $bashProfile
        Install-JaxShellIntegration -Shell zsh, bash -InstallRoot $shellRoot `
            -ZshProfilePath $zshProfile -BashProfilePath $bashProfile

        Test-Path -LiteralPath (Join-Path $shellRoot 'Jax.ShellLauncher.ps1') | Should -BeTrue
        ([regex]::Matches((Get-Content -LiteralPath $zshProfile -Raw), '# >>> jax CLI >>>')).Count |
            Should -Be 1
        ([regex]::Matches((Get-Content -LiteralPath $bashProfile -Raw), '# >>> jax CLI >>>')).Count |
            Should -Be 1
    }

    It 'uses the platform default Unix shell when SHELL is unavailable' -Skip:($IsWindows) {
        Import-Module (Join-Path $script:installRoot 'Jax.psd1') -Force
        $shellRoot = Join-Path $script:testRoot 'default-shell-integration'
        $powerShellProfile = Join-Path $script:testRoot 'default-shell-profiles/profile.ps1'
        $zshProfile = Join-Path $script:testRoot 'default-shell-profiles/.zshrc'
        $bashProfile = Join-Path $script:testRoot 'default-shell-profiles/.bashrc'
        $previousShell = $env:SHELL
        try {
            Remove-Item Env:SHELL -ErrorAction SilentlyContinue
            Install-JaxShellIntegration -InstallRoot $shellRoot `
                -PowerShellProfilePath $powerShellProfile `
                -ZshProfilePath $zshProfile -BashProfilePath $bashProfile
        } finally {
            if ($null -eq $previousShell) {
                Remove-Item Env:SHELL -ErrorAction SilentlyContinue
            } else {
                $env:SHELL = $previousShell
            }
        }

        Test-Path -LiteralPath $powerShellProfile | Should -BeTrue
        if ($IsMacOS) {
            Test-Path -LiteralPath $zshProfile | Should -BeTrue
        } else {
            Test-Path -LiteralPath $bashProfile | Should -BeTrue
        }
    }

    It 'pins source installs in PowerShell, zsh, and bash profiles' -Skip:($IsWindows) {
        Import-Module (Join-Path $script:installRoot 'Jax.psd1') -Force
        $shellRoot = Join-Path $script:testRoot 'source-shell-integration'
        $powerShellProfile = Join-Path $script:testRoot 'source-profiles/profile.ps1'
        $zshProfile = Join-Path $script:testRoot 'source-profiles/.zshrc'
        $bashProfile = Join-Path $script:testRoot 'source-profiles/.bashrc'
        $modulePath = Join-Path $script:installRoot 'Jax.psd1'

        Install-JaxShellIntegration -Shell powershell, zsh, bash -ModulePath $modulePath `
            -InstallRoot $shellRoot -PowerShellProfilePath $powerShellProfile `
            -ZshProfilePath $zshProfile -BashProfilePath $bashProfile

        (Get-Content -LiteralPath $powerShellProfile -Raw) |
            Should -Match ([regex]::Escape($modulePath))
        (Get-Content -LiteralPath $zshProfile -Raw) |
            Should -Match 'export JAX_MODULE_PATH='
        (Get-Content -LiteralPath $bashProfile -Raw) |
            Should -Match 'export JAX_MODULE_PATH='
    }

    It 'routes zsh and bash arguments through the installed PowerShell module' `
        -Skip:($IsWindows -or $null -eq (Get-Command zsh -ErrorAction SilentlyContinue) -or $null -eq (Get-Command bash -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path $script:installRoot 'Jax.psd1') -Force
        $shellRoot = Join-Path $script:testRoot 'shell-routing'
        Install-JaxShellIntegration -Shell zsh, bash -InstallRoot $shellRoot `
            -ZshProfilePath (Join-Path $script:testRoot 'routing.zshrc') `
            -BashProfilePath (Join-Path $script:testRoot 'routing.bashrc')
        $previousModulePath = $env:JAX_MODULE_PATH
        $env:JAX_MODULE_PATH = Join-Path $script:installRoot 'Jax.psd1'
        try {
            $zshOutput = & zsh -fc 'source "$1"; shift; jax "$@"' jax-test `
                (Join-Path $shellRoot 'jax.zsh') -C $script:consumerRoot info -q 2>&1 | Out-String
            $zshExit = $LASTEXITCODE
            $bashOutput = & bash -c 'source "$1"; shift; jax "$@"' jax-test `
                (Join-Path $shellRoot 'jax.bash') -C $script:consumerRoot info -q 2>&1 | Out-String
            $bashExit = $LASTEXITCODE
        } finally {
            if ($null -eq $previousModulePath) {
                Remove-Item Env:JAX_MODULE_PATH -ErrorAction SilentlyContinue
            } else {
                $env:JAX_MODULE_PATH = $previousModulePath
            }
        }

        $zshExit | Should -Be 0 -Because $zshOutput
        $bashExit | Should -Be 0 -Because $bashOutput
        $zshOutput | Should -Match 'Target repository:'
        $bashOutput | Should -Match 'Target repository:'
    }

    It 'provides dynamic completion to non-PowerShell shell bridges' -Skip:($IsWindows) {
        $completionConsumer = Join-Path $script:testRoot 'completion-consumer'
        New-Item -ItemType Directory -Path $completionConsumer -Force | Out-Null
        & git -C $completionConsumer init --quiet
        & (Join-Path $script:installRoot 'jax.ps1') -C $completionConsumer `
            init -client sample -env dev -q | Out-Null
        $previousModulePath = $env:JAX_MODULE_PATH
        $env:JAX_MODULE_PATH = Join-Path $script:installRoot 'Jax.psd1'
        $previousRepoRoot = $env:JAX_REPO_ROOT
        $env:JAX_REPO_ROOT = $completionConsumer
        try {
            $completionOutput = & pwsh -NoLogo -NoProfile `
                -File (Join-Path $script:installRoot 'shell/Jax.ShellCompletion.ps1') `
                'jax -e ' 7
        } finally {
            if ($null -eq $previousModulePath) {
                Remove-Item Env:JAX_MODULE_PATH -ErrorAction SilentlyContinue
            } else {
                $env:JAX_MODULE_PATH = $previousModulePath
            }
            if ($null -eq $previousRepoRoot) {
                Remove-Item Env:JAX_REPO_ROOT -ErrorAction SilentlyContinue
            } else {
                $env:JAX_REPO_ROOT = $previousRepoRoot
            }
        }

        @($completionOutput) | Should -Contain 'sample/dev/build'
    }

    It 'caches Gallery version checks and makes offline retries cheap' {
        Import-Module (Join-Path $script:installRoot 'Jax.psd1') -Force
        $cachePath = Join-Path $script:testRoot 'update-check.json'
        Mock -CommandName Invoke-WebRequest -ModuleName Jax {
            throw 'offline'
        }

        $first = Get-JaxUpdateStatus -CachePath $cachePath -Force
        $second = Get-JaxUpdateStatus -CachePath $cachePath

        $first.Status | Should -Be 'Unavailable'
        $first.Source | Should -Be 'gallery'
        $second.Status | Should -Be 'Unavailable'
        $second.Source | Should -Be 'cache'
        Assert-MockCalled -CommandName Invoke-WebRequest -ModuleName Jax -Times 1
    }

    It 'refuses to replace an unrelated existing directory' {
        $installer = Join-Path $script:sourceRoot 'Install-Jax.ps1'
        $unrelatedRoot = Join-Path $script:testRoot 'unrelated-install'
        New-Item -ItemType Directory -Path $unrelatedRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $unrelatedRoot 'keep.txt') -Value 'keep'

        { & $installer -InstallRoot $unrelatedRoot -SkipProfile } |
            Should -Throw '*not an installed Jax module*'
        (Get-Content -LiteralPath (Join-Path $unrelatedRoot 'keep.txt') -Raw).Trim() | Should -Be 'keep'
    }

    It 'rejects a filesystem root as an install target' {
        $installer = Join-Path $script:sourceRoot 'Install-Jax.ps1'
        $filesystemRoot = [IO.Path]::GetPathRoot($script:testRoot)
        { & $installer -InstallRoot $filesystemRoot -SkipProfile } | Should -Throw '*unsafe install root*'
    }

    It 'exposes the jax command from the installed module' {
        Import-Module (Join-Path $script:installRoot 'Jax.psd1') -Force
        $jaxCommand = Get-Command jax -ErrorAction Stop
        $jxCommand = Get-Command jx -ErrorAction Stop
        $jaxCommand.CommandType | Should -Be 'Alias'
        $jaxCommand.Definition | Should -Be (Join-Path $script:installRoot 'jax.ps1')
        $jxCommand.Definition | Should -Be 'jax'
        $jaxCommand.Parameters.Keys | Should -Contain 'env'
    }

    It 'initializes and runs a clean consumer from outside its repository' {
        $launcher = Join-Path $script:installRoot 'jax.ps1'
        $outside = Join-Path $script:testRoot 'outside'
        New-Item -ItemType Directory -Path $outside -Force | Out-Null

        Push-Location $outside
        try {
            $initOutput = & $launcher -C $script:consumerRoot init -client sample -env dev -q *>&1 | Out-String
            $envOutput = & $launcher -RepoRoot $script:consumerRoot list-envs -q *>&1 | Out-String
            $taskOutput = & $launcher -C $script:consumerRoot list-tasks -env sample/dev -q *>&1 | Out-String
            $runOutput = & $launcher -C $script:consumerRoot run -env sample/dev -only Build -noSavedSettings -q *>&1 | Out-String
        } finally {
            Pop-Location
        }

        $initOutput | Should -Not -Match 'Exception|Error'
        Test-Path -LiteralPath (Join-Path $script:consumerRoot '.jax/jax.config.yml') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:consumerRoot 'env/sample/dev/flows/build.yml') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:consumerRoot 'env/sample/dev/psakefile.ps1') | Should -BeTrue
        $envOutput | Should -Match 'sample/dev'
        $taskOutput | Should -Match 'Build'
        $runOutput | Should -Match 'Build task'
    }

    It 'completes environments through the installed jax and jx aliases' {
        Register-JaxCompletion
        $previousRepoRoot = $env:JAX_REPO_ROOT
        $env:JAX_REPO_ROOT = $script:consumerRoot
        try {
            foreach ($input in @('jax -e ', 'jx -e ')) {
                $completion = TabExpansion2 -InputScript $input -CursorColumn $input.Length
                @($completion.CompletionMatches | ForEach-Object CompletionText) |
                    Should -Contain 'sample/dev/build'
            }
        } finally {
            if ($null -ne $previousRepoRoot) {
                $env:JAX_REPO_ROOT = $previousRepoRoot
            } else {
                Remove-Item Env:JAX_REPO_ROOT -ErrorAction SilentlyContinue
            }
        }
    }

    It 'keeps repository-mutating commands scoped to -C' {
        $launcher = Join-Path $script:installRoot 'jax.ps1'
        $callerRoot = Join-Path $script:testRoot 'caller'
        New-Item -ItemType Directory -Path $callerRoot -Force | Out-Null

        Push-Location $callerRoot
        try {
            & $launcher -C $script:consumerRoot create-flavour '-Name=targeted' '-Description=targeted'
            & $launcher -C $script:consumerRoot env init targeted-env targeted-client build default
            & $launcher -C $script:consumerRoot run -env sample/dev -only Build -ssc targeted -q
            $shortcutOutput = & $launcher -C $script:consumerRoot -sc targeted -q *>&1 | Out-String
            & $launcher -C $script:consumerRoot -rsc targeted -q
        } finally {
            Pop-Location
        }

        Test-Path -LiteralPath (Join-Path $script:consumerRoot 'configs/jax-flavours/targeted.yml') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:consumerRoot 'env/targeted-client/targeted-env') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $callerRoot 'configs/jax-flavours/targeted.yml') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $callerRoot '.jax/jax.shortcut.yml') | Should -BeFalse
        $shortcutOutput | Should -Match 'Build task'
        Get-Content -LiteralPath (Join-Path $script:consumerRoot '.jax/jax.shortcut.yml') -Raw |
            Should -Not -Match '(?m)^\s*targeted:'
    }

    It 'installs the bundled agent skill into a consumer repository' {
        $launcher = Join-Path $script:installRoot 'jax.ps1'
        $skillOutput = & $launcher -C $script:consumerRoot skill -q *>&1 | Out-String
        $skillPath = Join-Path $script:consumerRoot '.agents/skills/jax/SKILL.md'

        $skillOutput | Should -Match 'Jax AI-agent skill installed'
        Test-Path -LiteralPath $skillPath | Should -BeTrue
        Get-Content -LiteralPath $skillPath -Raw | Should -Match '(?m)^name: jax\r?$'
    }

    It 'reports installed runtime and consumer configuration diagnostics' {
        $launcher = Join-Path $script:installRoot 'jax.ps1'
        $infoOutput = & $launcher -C $script:consumerRoot info -q *>&1 | Out-String

        $infoOutput | Should -Match 'Jax diagnostics'
        $expectedVersion = [regex]::Escape((Get-Content -LiteralPath (Join-Path $script:sourceRoot 'VERSION') -Raw).Trim())
        $infoOutput | Should -Match "Version: $expectedVersion"
        $infoOutput | Should -Match 'Runtime root:'
        $infoOutput | Should -Match 'Install source commit:'
        $infoOutput | Should -Match 'Target repository:'
        $infoOutput | Should -Match 'Repository config: present'
        $infoOutput | Should -Match 'Local state: absent'
    }

    It 'reports a configured non-default environment root' {
        $launcher = Join-Path $script:installRoot 'jax.ps1'
        $configPath = Join-Path $script:consumerRoot '.jax/jax.config.yml'
        $customEnvRoot = Join-Path $script:consumerRoot 'custom-env'
        Set-Content -LiteralPath $configPath -Value @'
jax:
  envRoot: custom-env
'@
        New-Item -ItemType Directory -Path $customEnvRoot -Force | Out-Null

        $infoOutput = & $launcher -C $script:consumerRoot info -q *>&1 | Out-String

        $infoOutput | Should -Match 'Environment root: present \(custom-env/\)'
    }

    It 'refuses to uninstall an unrelated directory' {
        $uninstaller = Join-Path $script:sourceRoot 'Uninstall-Jax.ps1'
        $unrelatedRoot = Join-Path $script:testRoot 'unrelated'
        New-Item -ItemType Directory -Path $unrelatedRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $unrelatedRoot 'keep.txt') -Value 'keep'

        { & $uninstaller -InstallRoot $unrelatedRoot -ProfilePath $script:profilePath `
                -ZshProfilePath (Join-Path $script:testRoot '.zshrc') `
                -BashProfilePath (Join-Path $script:testRoot '.bashrc') -Confirm:$false } |
            Should -Throw '*not a Jax installation*'
        Test-Path -LiteralPath (Join-Path $unrelatedRoot 'keep.txt') | Should -BeTrue
    }

    It 'refuses to uninstall the Jax source checkout' {
        $uninstaller = Join-Path $script:sourceRoot 'Uninstall-Jax.ps1'

        { & $uninstaller -InstallRoot $script:sourceRoot -ProfilePath $script:profilePath `
                -ZshProfilePath (Join-Path $script:testRoot '.zshrc') `
                -BashProfilePath (Join-Path $script:testRoot '.bashrc') -Confirm:$false } |
            Should -Throw '*not a Jax installation*'
        Test-Path -LiteralPath (Join-Path $script:sourceRoot 'Jax.psd1') | Should -BeTrue
    }

    It 'uninstalls the module and removes only its marked profile block' {
        $uninstaller = Join-Path $script:sourceRoot 'Uninstall-Jax.ps1'
        $zshProfile = Join-Path $script:testRoot '.zshrc'
        $bashProfile = Join-Path $script:testRoot '.bashrc'
        Set-Content -LiteralPath $zshProfile -Value "# >>> jax CLI >>>`nsource jax.zsh`n# <<< jax CLI <<<"
        Set-Content -LiteralPath $bashProfile -Value "# >>> jax CLI >>>`nsource jax.bash`n# <<< jax CLI <<<"
        & $uninstaller -InstallRoot $script:installRoot -ProfilePath $script:profilePath `
            -ZshProfilePath $zshProfile -BashProfilePath $bashProfile -Confirm:$false

        Test-Path -LiteralPath $script:installRoot | Should -BeFalse
        (Get-Content -LiteralPath $script:profilePath -Raw) | Should -Not -Match '# >>> jax CLI >>>'
        (Get-Content -LiteralPath $zshProfile -Raw) | Should -Not -Match '# >>> jax CLI >>>'
        (Get-Content -LiteralPath $bashProfile -Raw) | Should -Not -Match '# >>> jax CLI >>>'
    }
}
