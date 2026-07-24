function Invoke-JaxCoverageMaintenanceScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $Label,

        [hashtable] $ScriptArguments = @{}
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    $previousLastExitCode = $global:LASTEXITCODE
    try {
        $global:LASTEXITCODE = 0
        & $Path @ScriptArguments
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "[coverage-plugin] $Label exited with code $LASTEXITCODE"
        }
    } catch {
        Write-Warning "[coverage-plugin] $Label failed: $_"
    } finally {
        $global:LASTEXITCODE = $previousLastExitCode
    }
}

function Register-JaxCoveragePlugin {
    [CmdletBinding()]
    param()

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    if ($null -eq $commonParams) {
        $commonParams = @{}
    }

    $hooks = @{
        # Resolve -coverage / -nocoverage against persisted preference and stash the
        # effective state on the run context. Mirrors the vault plugin's pattern.
        'BeforeRunHeader'  = {
            param($hook)
            $context = $hook.Context
            $pluginConfig = $hook.PluginConfig

            $resolved = $null
            if ($hook.Data -and $hook.Data.ContainsKey('Resolved')) {
                $resolved = $hook.Data['Resolved']
            }

            $coverageEnabled = $false
            if ($pluginConfig -and $pluginConfig -is [System.Collections.IDictionary]) {
                if ($pluginConfig.Contains('enabled') -and $pluginConfig['enabled'] -is [bool]) {
                    $coverageEnabled = [bool]$pluginConfig['enabled']
                }
            }

            $statePref = $null
            if ($context.ContainsKey('State') -and $context['State'] -is [System.Collections.IDictionary]) {
                $st = $context['State']
                if ($st.Contains('plugins') -and $st['plugins'] -is [System.Collections.IDictionary]) {
                    $plugins = $st['plugins']
                    if ($plugins.Contains('coverage') -and $plugins['coverage'] -is [System.Collections.IDictionary]) {
                        $prefs = $plugins['coverage']
                        if ($prefs.Contains('enabled') -and $prefs['enabled'] -is [bool]) {
                            $statePref = [bool]$prefs['enabled']
                        }
                    }
                }
            }
            if ($statePref -is [bool]) {
                $coverageEnabled = $statePref
            }

            $cliOverride = $null
            if ($resolved -and $resolved -is [System.Collections.IDictionary]) {
                if ($resolved.Contains('nocoverage') -and [bool]$resolved['nocoverage']) { $cliOverride = $false }
                elseif ($resolved.Contains('coverage') -and [bool]$resolved['coverage']) { $cliOverride = $true }
            }
            # Pre-set *_COVERAGE = true (e.g. from a CI step environment) signals
            # opt-in equivalent to passing -coverage on the CLI. Without this the
            # plugin would strip the env vars below and tests would silently lose
            # their --coverage flags.
            if ($null -eq $cliOverride -and (
                    $env:VITEST_COVERAGE  -eq 'true' -or
                    $env:FLUTTER_COVERAGE -eq 'true' -or
                    $env:SWIFT_COVERAGE   -eq 'true' -or
                    $env:PYTHON_COVERAGE  -eq 'true' -or
                    $env:PESTER_COVERAGE  -eq 'true'
                )) {
                $cliOverride = $true
            }
            if ($cliOverride -is [bool]) {
                $coverageEnabled = $cliOverride

                $noSave = $false
                if ($context.ContainsKey('NoSavedSettings') -and [bool]$context['NoSavedSettings']) { $noSave = $true }
                if ($resolved -and $resolved.Contains('noSavedSettings') -and [bool]$resolved['noSavedSettings']) { $noSave = $true }

                if (-not $noSave) {
                    Update-JaxState -RepoRoot $context['RepoRoot'] -Updates @{ plugins = @{ coverage = @{ enabled = $coverageEnabled } } } | Out-Null
                }
            }

            if ($resolved -and $resolved -is [System.Collections.IDictionary]) {
                $resolved['coverageEnabledOverride'] = $coverageEnabled
            }
            $context['CoverageEnabledOverride'] = $coverageEnabled

            # Wipe coverage/ at run start so stale coverage-final.json from a
            # prior run doesn't get picked up by the merge step.
            if ($coverageEnabled) {
                $repoRoot = $context['RepoRoot']
                if (-not [string]::IsNullOrWhiteSpace($repoRoot)) {
                    $coverageRoot = Join-Path $repoRoot 'coverage'
                    if (Test-Path -LiteralPath $coverageRoot) {
                        try {
                            Remove-Item -LiteralPath $coverageRoot -Recurse -Force -ErrorAction Stop
                        } catch {
                            Write-Warning "[coverage-plugin] Could not clear $coverageRoot before run: $_"
                        }
                    }
                }
            }
        }

        # Set or clear the per-language coverage env vars + $env:COVERAGE_DIR before
        # each entity. COVERAGE_DIR is per-entity so multi-task runs don't overwrite
        # each other; it's built from <SourcePath relative to repo root>--<entity name>,
        # sanitized for filesystem use. Originals are restored in AfterRunEntities.
        #
        # Each language helper reads its own env var (VITEST_COVERAGE → Invoke-VitestProject,
        # FLUTTER_COVERAGE → Invoke-FlutterTestProject, SWIFT_COVERAGE → Invoke-SwiftTestProject)
        # so the single `-coverage` jax flag transparently covers TS, Dart/Flutter, and Swift
        # tasks without each helper needing to know about the others.
        'BeforeRunEntity'  = {
            param($hook)
            $context = $hook.Context
            $data = $hook.Data

            $coverageEnvNames = @('VITEST_COVERAGE', 'FLUTTER_COVERAGE', 'SWIFT_COVERAGE', 'PYTHON_COVERAGE', 'PESTER_COVERAGE', 'COVERAGE_DIR')

            if (-not $context.ContainsKey('CoverageEnvSnapshot')) {
                $snapshot = @{}
                foreach ($name in $coverageEnvNames) {
                    $snapshot[$name] = @{
                        WasSet = (Test-Path "Env:$name")
                        Value  = (Get-Item "Env:$name" -ErrorAction SilentlyContinue).Value
                    }
                }
                $context['CoverageEnvSnapshot'] = $snapshot
            }

            $coverageEnabled = $false
            if ($context.ContainsKey('CoverageEnabledOverride') -and $context['CoverageEnabledOverride'] -is [bool]) {
                $coverageEnabled = [bool]$context['CoverageEnabledOverride']
            }

            $context['CoverageEnabled'] = $coverageEnabled

            if (-not $coverageEnabled) {
                foreach ($name in $coverageEnvNames) {
                    Remove-Item "Env:$name" -ErrorAction SilentlyContinue
                }
                return
            }

            $env:VITEST_COVERAGE  = 'true'
            $env:FLUTTER_COVERAGE = 'true'
            $env:SWIFT_COVERAGE   = 'true'
            $env:PYTHON_COVERAGE  = 'true'
            $env:PESTER_COVERAGE  = 'true'

            # Build a stable, unique-per-entity coverage subdir.
            $entity = $null
            if ($null -ne $data -and $data.Contains('Entity')) { $entity = $data['Entity'] }
            $entityName = $null
            $sourcePath = $null
            $entityTasks = $null
            $entityScript = $null
            if ($entity -is [System.Collections.IDictionary]) {
                if ($entity.Contains('Name')) { $entityName = [string]$entity['Name'] }
                if ($entity.Contains('SourcePath')) { $sourcePath = [string]$entity['SourcePath'] }
                if ($entity.Contains('Tasks')) { $entityTasks = $entity['Tasks'] }
                if ($entity.Contains('Script')) { $entityScript = [string]$entity['Script'] }
                if ([string]::IsNullOrWhiteSpace($entityName) -and $entity.Contains('Key')) { $entityName = [string]$entity['Key'] }
            } elseif ($null -ne $entity) {
                $props = $entity.PSObject.Properties
                if ($props.Match('Name').Count -gt 0) { $entityName = [string]$entity.Name }
                if ($props.Match('SourcePath').Count -gt 0) { $sourcePath = [string]$entity.SourcePath }
                if ($props.Match('Tasks').Count -gt 0) { $entityTasks = $entity.Tasks }
                if ($props.Match('Script').Count -gt 0) { $entityScript = [string]$entity.Script }
                if ([string]::IsNullOrWhiteSpace($entityName) -and $props.Match('Key').Count -gt 0) { $entityName = [string]$entity.Key }
            }
            if ([string]::IsNullOrWhiteSpace($entityName)) {
                if ($null -ne $entityTasks) {
                    if ($entityTasks -is [string]) {
                        $entityName = $entityTasks
                    } else {
                        $entityName = (@($entityTasks) -join '+')
                    }
                }
            }
            if ([string]::IsNullOrWhiteSpace($entityName) -and -not [string]::IsNullOrWhiteSpace($entityScript)) {
                $entityName = [System.IO.Path]::GetFileNameWithoutExtension($entityScript)
            }

            $repoRoot = $context['RepoRoot']
            $relSource = $null
            if (-not [string]::IsNullOrWhiteSpace($sourcePath) -and -not [string]::IsNullOrWhiteSpace($repoRoot)) {
                try {
                    $relSource = [System.IO.Path]::GetRelativePath($repoRoot, $sourcePath)
                } catch {
                    $relSource = $sourcePath
                }
            }

            $segments = @()
            if (-not [string]::IsNullOrWhiteSpace($relSource)) { $segments += $relSource }
            if (-not [string]::IsNullOrWhiteSpace($entityName)) { $segments += $entityName }
            if ($segments.Count -eq 0) { $segments = @('unknown') }

            $raw = $segments -join '--'
            $sanitized = ($raw -replace '[\\/:\s.]+', '-' -replace '[^A-Za-z0-9_-]', '_').Trim('-', '_')
            if ([string]::IsNullOrWhiteSpace($sanitized)) { $sanitized = 'entity' }

            $env:COVERAGE_DIR = "coverage/$sanitized"
        }

        # Restore env vars and merge per-entity coverage into a single repo-level report.
        'AfterRunEntities' = {
            param($hook)
            $context = $hook.Context
            if (-not $context.ContainsKey('CoverageEnvSnapshot')) {
                return
            }

            $coverageWasEnabled = $context.ContainsKey('CoverageEnabledOverride') -and [bool]$context['CoverageEnabledOverride']

            $snapshot = $context['CoverageEnvSnapshot']
            foreach ($name in @('VITEST_COVERAGE', 'FLUTTER_COVERAGE', 'SWIFT_COVERAGE', 'PYTHON_COVERAGE', 'PESTER_COVERAGE', 'COVERAGE_DIR')) {
                $snap = $snapshot[$name]
                if ($null -eq $snap) { continue }

                $wasSet = $false
                if ($snap.ContainsKey('WasSet')) { $wasSet = [bool]$snap['WasSet'] }
                if ($wasSet) {
                    $value = $null
                    if ($snap.ContainsKey('Value')) { $value = $snap['Value'] }
                    if ($null -ne $value) {
                        Set-Item -Path "Env:$name" -Value $value -ErrorAction SilentlyContinue | Out-Null
                    } else {
                        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
                    }
                } else {
                    Remove-Item "Env:$name" -ErrorAction SilentlyContinue
                }
            }

            if (-not $coverageWasEnabled) { return }

            $repoRoot = $context['RepoRoot']
            if ([string]::IsNullOrWhiteSpace($repoRoot)) { return }
            $coverageRoot = Join-Path $repoRoot 'coverage'

            if (-not (Test-Path -LiteralPath $coverageRoot)) {
                Write-Host "[coverage-plugin] No coverage outputs were produced; skipping coverage merge." -ForegroundColor DarkGray
                return
            }

            # Step 1 — Vitest per-project coverage-final.json → repo-root
            # JSON+lcov via nyc merge. Only runs when there's something to
            # merge (the script no-ops on missing inputs).
            $mergeScript = Join-Path $repoRoot 'devops/ci/merge-coverage.ps1'
            if (Test-Path -LiteralPath $mergeScript) {
                Write-Host "[coverage-plugin] Merging per-entity Vitest coverage into $coverageRoot ..." -ForegroundColor Cyan
                Invoke-JaxCoverageMaintenanceScript -Path $mergeScript -Label 'merge-coverage' -ScriptArguments @{
                    CoverageRoot = $coverageRoot
                }
            }

            # Step 2 — concatenate every per-package <pkg>/coverage/lcov.info
            # (Flutter, Swift, pytest, and Vitest's merged lcov from step 1)
            # into one repo-root coverage/lcov.info with absolute paths.
            # Coverage Gutters reads ONE file rather than scanning all
            # subdirs — visibly faster for monorepos with many packages.
            $mergeLcovScript = Join-Path $repoRoot 'devops/ci/merge-lcov.ps1'
            if (Test-Path -LiteralPath $mergeLcovScript) {
                Write-Host "[coverage-plugin] Concatenating per-package lcov files into $coverageRoot/lcov.info ..." -ForegroundColor Cyan
                Invoke-JaxCoverageMaintenanceScript -Path $mergeLcovScript -Label 'merge-lcov' -ScriptArguments @{
                    RepoRoot = $repoRoot
                }
            }

        }
    }

    Register-JaxPlugin -Name 'coverage' -Hooks $hooks -SourcePath $MyInvocation.MyCommand.Path @commonParams
}

Register-JaxCoveragePlugin
