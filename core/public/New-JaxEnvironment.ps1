function New-JaxEnvironment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [string] $Client,

        [Parameter(Mandatory = $false)]
        [string] $DefaultFlow,

        [Parameter(Mandatory = $false)]
        [string] $Template = 'default',

        [Parameter(Mandatory = $false)]
        [string] $RepoRoot = (Get-JaxRepoRoot)
    )

    # $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    $repoRoot = [IO.Path]::GetFullPath($RepoRoot)
    $config = Get-JaxConfig -RepoRoot $repoRoot

    # 1. Resolve Environment Name
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = Read-Host "Enter Environment Name"
        if ([string]::IsNullOrWhiteSpace($Name)) {
            Write-Error "Environment name cannot be empty."
            return
        }
    }

    # 2. Resolve Client Scope
    if ([string]::IsNullOrWhiteSpace($Client)) {
        # Check if user wants to specify client
        $hasClient = Read-JaxPromptBool -Prompt "Is this environment for a specific client?" -Default $false
        if ($hasClient) {
            $Client = Read-Host "Enter Client Name"
            if ([string]::IsNullOrWhiteSpace($Client)) {

                Write-Error "Client name cannot be empty if specified."
                return
            }
        }
    }

    # 3. Resolve Default Flow
    if ([string]::IsNullOrWhiteSpace($DefaultFlow)) {
        $DefaultFlow = Read-Host "Enter Default Flow Name (default: build)"
        if ([string]::IsNullOrWhiteSpace($DefaultFlow)) {
            $DefaultFlow = 'build'
        }
    }

    # 4. Resolve Template (if not explicitly provided)
    $templatesBaseDir = Join-Path (Get-JaxToolRoot) 'templates/env'
    if (-not $PSBoundParameters.ContainsKey('Template') -and (Test-Path $templatesBaseDir)) {
        # Discover available templates
        $availableTemplates = @(Get-ChildItem -Path $templatesBaseDir -Directory | Select-Object -ExpandProperty Name | Sort-Object)
        if ($availableTemplates.Count -gt 1) {
            Write-Host "Select template (↑/↓ to navigate, Enter to select):" -ForegroundColor Cyan

            # Find default index
            $selectedIndex = 0
            for ($i = 0; $i -lt $availableTemplates.Count; $i++) {
                if ($availableTemplates[$i] -eq 'default') {
                    $selectedIndex = $i
                    break
                }
            }

            # Interactive selection
            $done = $false
            while (-not $done) {
                # Clear and redraw options
                for ($i = 0; $i -lt $availableTemplates.Count; $i++) {
                    $marker = if ($availableTemplates[$i] -eq 'default') { ' (default)' } else { '' }
                    if ($i -eq $selectedIndex) {
                        Write-Host "  > $($availableTemplates[$i])$marker" -ForegroundColor Green
                    } else {
                        Write-Host "    $($availableTemplates[$i])$marker" -ForegroundColor Gray
                    }
                }

                # Read key
                $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

                switch ($key.VirtualKeyCode) {
                    38 { # Up arrow
                        $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $availableTemplates.Count - 1 }
                    }
                    40 { # Down arrow
                        $selectedIndex = if ($selectedIndex -lt $availableTemplates.Count - 1) { $selectedIndex + 1 } else { 0 }
                    }
                    13 { # Enter
                        $done = $true
                    }
                }

                # Move cursor up to redraw (clear previous lines)
                if (-not $done) {
                    for ($i = 0; $i -lt $availableTemplates.Count; $i++) {
                        [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
                        Write-Host (" " * 60)
                        [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
                    }
                }
            }

            $Template = $availableTemplates[$selectedIndex]
            Write-Host "Selected: $Template" -ForegroundColor Green
        }
    }

    # 4. Determine Paths
    $envRootVar = 'env'
    if ($null -ne $config -and $config.ContainsKey('envRoot')) {
        $envRootVar = $config['envRoot']
    }
    $envRootFromConfig = $envRootVar

    $envRootPath = Join-Path $repoRoot $envRootFromConfig

    $targetEnvPath = if (-not [string]::IsNullOrWhiteSpace($Client)) {
        Join-Path $envRootPath $Client
    } else {
        $envRootPath # If no client, is it common or root?
        # User requested: "if specifid env... then common/scripts/scenarios-lib should be reated there"
        # Wait, usually environments are specific directories.
        # If no client, we probably want $EnvRoot/Name (like sample-app)
        # Assuming common environments exist at root of env/
    }

    # Correct path logic:
    # If client: env/client/name
    # If no client: env/name
    if (-not [string]::IsNullOrWhiteSpace($Client)) {
        $targetEnvPath = Join-Path $envRootPath $Client
        $targetEnvPath = Join-Path $targetEnvPath $Name
    } else {
        $targetEnvPath = Join-Path $envRootPath $Name
    }

    Write-Host "Creating environment '$Name' at: $targetEnvPath" -ForegroundColor Cyan

    if (Test-Path $targetEnvPath) {
        Write-Warning "Directory already exists at $targetEnvPath. Skipping creation."
        # Optional: Ask to overwrite? For now, abort to be safe.
        return
    }

    # 5. Create Directories
    $dirs = @('flows', 'scenarios-lib', 'library', 'scripts') # 'flows' per config default, can update if config differs
    foreach ($d in $dirs) {
        $p = Join-Path $targetEnvPath $d
        New-Item -ItemType Directory -Path $p -Force | Out-Null
    }

    # 6. Apply Templates
    $templateDir = Join-Path $templatesBaseDir $Template
    if (-not (Test-Path $templateDir)) {
        Write-Error "Template '$Template' not found at $templateDir"
        return
    }

    # Replacements
    $tokens = @{
        '{{EnvName}}'  = $Name
        '{{FlowName}}' = $DefaultFlow
    }

    # Helper to process file
    function Invoke-TemplateFileProcessing {
        param($Src, $Dst, $Tokens)
        $content = Get-Content -Path $Src -Raw
        foreach ($key in $Tokens.Keys) {
            $content = $content.Replace($key, $Tokens[$key])
        }
        Set-Content -Path $Dst -Value $content -Force -Encoding utf8
    }

    function ConvertTo-TemplateParamInt {
        param(
            [string] $Value
        )
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return $null
        }
        $parsed = 0
        $isOk = [int]::TryParse($Value.Trim(), [ref]$parsed)
        if (-not $isOk) {
            return $null
        }
        return $parsed
    }

    function Test-TemplateNodePort {
        param(
            [int] $Port,
            [int] $MinPort,
            [int] $MaxPort
        )
        if ($Port -lt $MinPort) { return $false }
        if ($Port -gt $MaxPort) { return $false }
        return $true
    }

    function Resolve-TemplateParameters {
        param(
            [System.Collections.IDictionary] $TemplateDef,
            [hashtable] $Tokens
        )

        if (-not $TemplateDef) { return $Tokens }
        if (-not ($TemplateDef.Contains('parameters') -and $TemplateDef.parameters)) { return $Tokens }

        $minNodePort = 30000
        $maxNodePort = 32767
        if ($TemplateDef.Contains('nodePortRangeStart')) {
            $minCandidate = ConvertTo-TemplateParamInt -Value ([string]$TemplateDef.nodePortRangeStart)
            if ($minCandidate) { $minNodePort = $minCandidate }
        }
        if ($TemplateDef.Contains('nodePortRangeEnd')) {
            $maxCandidate = ConvertTo-TemplateParamInt -Value ([string]$TemplateDef.nodePortRangeEnd)
            if ($maxCandidate) { $maxNodePort = $maxCandidate }
        }

        $uniqueGroups = @{}
        foreach ($paramDef in @($TemplateDef.parameters)) {
            if (-not $paramDef) { continue }

            $paramName = [string]$paramDef.name
            if ([string]::IsNullOrWhiteSpace($paramName)) { continue }

            $token = if ($paramDef.token) { [string]$paramDef.token } else { "{{${paramName}}}" }
            $prompt = if ($paramDef.prompt) { [string]$paramDef.prompt } else { $paramName }
            $type = if ($paramDef.type) { ([string]$paramDef.type).ToLowerInvariant() } else { 'string' }
            $required = $false
            if ($paramDef.required -is [bool]) { $required = [bool]$paramDef.required }

            $defaultRaw = $null
            if ($paramDef.Contains('default')) { $defaultRaw = $paramDef.default }

            $validators = @()
            if ($paramDef.validators) { $validators = @($paramDef.validators) }

            while ($true) {
                $value = $null

                if ($type -eq 'int') {
                    $raw = $null
                    $defaultText = $null
                    if ($null -ne $defaultRaw) { $defaultText = [string]$defaultRaw }
                    $raw = Read-Host ("{0}{1}" -f $prompt, $(if ($defaultText) { " (default: $defaultText)" } else { "" }))
                    if ([string]::IsNullOrWhiteSpace($raw) -and $defaultText) { $raw = $defaultText }
                    $value = ConvertTo-TemplateParamInt -Value $raw
                } else {
                    $raw = Read-Host $prompt
                    if ([string]::IsNullOrWhiteSpace($raw) -and $null -ne $defaultRaw) { $raw = [string]$defaultRaw }
                    $value = $raw
                }

                $isMissingRequired = $required -and ($null -eq $value -or ([string]$value).Trim() -eq '')
                if ($isMissingRequired) {
                    Write-Host "Value is required." -ForegroundColor Yellow
                    continue
                }

                $failedValidation = $false
                foreach ($validator in $validators) {
                    $v = ([string]$validator).Trim()
                    if ([string]::IsNullOrWhiteSpace($v)) { continue }

                    if ($v -eq 'nodePort') {
                        if ($null -eq $value) { continue }
                        if (-not (Test-TemplateNodePort -Port ([int]$value) -MinPort $minNodePort -MaxPort $maxNodePort)) {
                            Write-Host "Invalid NodePort. Must be in range $minNodePort-$maxNodePort." -ForegroundColor Yellow
                            $failedValidation = $true
                            break
                        }
                        continue
                    }

                    if ($v.StartsWith('unique:', [System.StringComparison]::OrdinalIgnoreCase)) {
                        $group = $v.Substring('unique:'.Length).Trim()
                        if ([string]::IsNullOrWhiteSpace($group)) { $group = 'default' }
                        if (-not $uniqueGroups.ContainsKey($group)) { $uniqueGroups[$group] = @() }
                        if ($null -ne $value) {
                            if ($uniqueGroups[$group] -contains $value) {
                                Write-Host "Value must be unique within group '$group'." -ForegroundColor Yellow
                                $failedValidation = $true
                                break
                            }
                        }
                        continue
                    }
                }
                if ($failedValidation) { continue }

                foreach ($validator in $validators) {
                    $v = ([string]$validator).Trim()
                    if ($v.StartsWith('unique:', [System.StringComparison]::OrdinalIgnoreCase)) {
                        $group = $v.Substring('unique:'.Length).Trim()
                        if ([string]::IsNullOrWhiteSpace($group)) { $group = 'default' }
                        if (-not $uniqueGroups.ContainsKey($group)) { $uniqueGroups[$group] = @() }
                        if ($null -ne $value) { $uniqueGroups[$group] += $value }
                    }
                }

                # Support token formatting variants (robust against accidental spacing).
                $tokenValue = [string]$value
                $Tokens[$token] = $tokenValue
                if ($token -match '^\{\{(.+)\}\}$') {
                    $inner = $Matches[1]
                    $Tokens["{{ $inner }}"] = $tokenValue
                    $Tokens["{ { $inner } }"] = $tokenValue
                }
                break
            }
        }

        return $Tokens
    }

    # Determine featured task + resolve template parameter tokens
    $featuredTask = 'Info'
    $templateDef = $null
    $templateDefPath = Join-Path $templateDir 'template.yml'
    if (Test-Path $templateDefPath) {
        $templateDef = Get-Content -Path $templateDefPath -Raw | ConvertFrom-Yaml
        if ($templateDef -and $templateDef.featuredTask) {
            $featuredTask = $templateDef.featuredTask
        }
    }
    if ($templateDef -and $templateDef -is [System.Collections.IDictionary]) {
        $tokens = Resolve-TemplateParameters -TemplateDef $templateDef -Tokens $tokens
    }

    # jaxfile.yml
    Invoke-TemplateFileProcessing -Src (Join-Path $templateDir 'jaxfile.yml') -Dst (Join-Path $targetEnvPath 'jaxfile.yml') -Tokens $tokens

    # flow.yml
    Invoke-TemplateFileProcessing -Src (Join-Path $templateDir 'flow.yml') -Dst (Join-Path $targetEnvPath "flows/$DefaultFlow.yml") -Tokens $tokens

    # psakefile.ps1
    Invoke-TemplateFileProcessing -Src (Join-Path $templateDir 'psakefile.ps1') -Dst (Join-Path $targetEnvPath 'psakefile.ps1') -Tokens $tokens

    # scenario.yml (disabled)
    Invoke-TemplateFileProcessing -Src (Join-Path $templateDir 'scenario.yml') -Dst (Join-Path $targetEnvPath 'scenarios-lib/example.yml.disabled') -Tokens $tokens

    # gitkeeps
    New-Item -ItemType File -Path (Join-Path $targetEnvPath 'library/.gitkeep') -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $targetEnvPath 'scripts/.gitkeep') -Force | Out-Null

    Write-Host "Environment '$Name' initialization complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Quick start:" -ForegroundColor Cyan
    $environmentKey = if ([string]::IsNullOrWhiteSpace($Client)) { $Name } else { "$Client/$Name" }
    Write-Host "  jax -e $environmentKey/$DefaultFlow $featuredTask" -ForegroundColor Gray


    # Reload info
    # Invoke-JaxModulesReload?
}
