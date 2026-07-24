Describe "New-JaxEnvironment" {
    # Mocks
    Mock Write-Host {}
    Mock Write-Warning {}
    Mock Write-Error {}

    # Mock Core Dependencies
    Mock Get-JaxCommonParameters { return @{} }

    BeforeAll {
        $sut = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../core/public/New-JaxEnvironment.ps1')).Path

        # Setup Test Repo Paths
        $script:testRoot = $null
        $script:testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "JaxTestrepo_$(Get-Random)"
        $templateDir = Join-Path $script:testRoot 'tool/templates/env/default'
        $envDir = Join-Path $script:testRoot 'env'

        # Create directories
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $templateDir -Force | Out-Null
        New-Item -ItemType Directory -Path $envDir -Force | Out-Null

        # Create dummy templates
        Set-Content -Path "$templateDir/jaxfile.yml" -Value "name: {{EnvName}}"
        Set-Content -Path "$templateDir/flow.yml" -Value "flow: {{FlowName}}"
        Set-Content -Path "$templateDir/psakefile.ps1" -Value "# Psake {{EnvName}}"
        Set-Content -Path "$templateDir/scenario.yml" -Value "# Scenario"
        Set-Content -Path "$templateDir/template.yml" -Value "featuredTask: Info"

        # --- STUBS (Replacing Pester Mocks for Scope Safety) ---
        # Control variables
        $script:StubRepoRoot = $script:testRoot
        $script:StubReadHostResponses = @{} # Key: substring match, Value: response
        $script:StubPromptBoolResponse = $false

        function Get-JaxRepoRoot { return $script:StubRepoRoot }
        function Get-JaxToolRoot { return (Join-Path $script:StubRepoRoot 'tool') }
        function Get-JaxConfig { return @{ envRoot = 'env' } }
        function Get-JaxCommonParameters { return @{} }

        function Read-JaxPromptBool {
            param($Prompt, $Default)
            return $script:StubPromptBoolResponse
        }

        function Read-Host {
            param($Prompt)
            # Find matching response
            foreach ($key in $script:StubReadHostResponses.Keys) {
                if ($Prompt -like "*$key*") {
                    return $script:StubReadHostResponses[$key]
                }
            }
            return "unknown_input"
        }

        function Write-Host {}
        function Write-Warning {}
        function Write-Error { param($Message) Write-Output "ERROR: $Message" }

        # Source the function
        . $sut
    }

    AfterAll {
        if ($null -ne $script:testRoot -and (Test-Path $script:testRoot)) {
            Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Structure Creation" {
        It "Creates Environment with Explicit Parameters (No Interaction)" {
            $envName = "automated-test-env"
            $client = "test-client"
            $flow = "ci"

            New-JaxEnvironment -Name $envName -Client $client -DefaultFlow $flow

            $targetPath = "$envDir/$client/$envName"

            $targetPath | Should -Exist
            "$targetPath/flows" | Should -Exist
            "$targetPath/scenarios-lib" | Should -Exist
            "$targetPath/jaxfile.yml" | Should -Exist
            "$targetPath/flows/$flow.yml" | Should -Exist

            # Check content replacement
            (Get-Content "$targetPath/jaxfile.yml" -Raw).Trim() | Should -Be "name: $envName"
            (Get-Content "$targetPath/flows/$flow.yml" -Raw).Trim() | Should -Be "flow: $flow"
        }

        It "Creates Root Environment (No Client)" {
            $envName = "root-env"

            New-JaxEnvironment -Name $envName -DefaultFlow "build"

            $targetPath = "$envDir/$envName"
            $targetPath | Should -Exist
        }

        It "Creates the environment in an explicitly targeted repository" {
            $targetRepo = Join-Path $script:testRoot 'target-repo'
            New-Item -ItemType Directory -Path $targetRepo -Force | Out-Null

            New-JaxEnvironment -Name 'targeted-env' -Client 'target-client' -DefaultFlow 'build' -RepoRoot $targetRepo

            (Join-Path $targetRepo 'env/target-client/targeted-env') | Should -Exist
            (Join-Path $script:testRoot 'env/target-client/targeted-env') | Should -Not -Exist
        }
    }

    Context "Interactive Prompts" {
        It "Prompts for Missing Parameters" {
            # Setup inputs
            $script:StubReadHostResponses = @{
                "Environment Name" = "interactive-env"
                "Client Name"      = "interactive-client"
                "Flow Name"        = "interactive-flow"
            }
            $script:StubPromptBoolResponse = $true

            New-JaxEnvironment

            $targetPath = "$envDir/interactive-client/interactive-env"
            $targetPath | Should -Exist
            "$targetPath/flows/interactive-flow.yml" | Should -Exist
        }
    }
}
