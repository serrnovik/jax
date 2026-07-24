function Get-JaxPsakeTaskInfoByParsing {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $FilePath,
        [switch] $NoCache,
        # Internal: tracks files already visited so recursive Include
        # resolution cannot loop. Callers should leave this empty; the function
        # repopulates it on each recursive call.
        [Parameter(DontShow = $true)]
        [System.Collections.Generic.HashSet[string]] $VisitedFiles
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        return @{
            TaskNames  = @()
            Parameters = @()
        }
    }

    if ($null -eq $VisitedFiles) {
        $VisitedFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }
    try {
        $normalizedPath = [System.IO.Path]::GetFullPath($FilePath)
    } catch {
        $normalizedPath = $FilePath
    }
    if (-not $VisitedFiles.Add($normalizedPath)) {
        return @{
            TaskNames  = @()
            Parameters = @()
        }
    }

    $contentRaw = Get-Content -Path $FilePath -Raw -ErrorAction Stop

    $taskNames = @()
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput($contentRaw, [ref]$null, [ref]$null)
    $commands = $scriptAst.FindAll({
            param($ast)
            $ast -is [System.Management.Automation.Language.CommandAst] -and
            $ast.CommandElements.Count -gt 1 -and
            $ast.CommandElements[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
            $ast.CommandElements[0].Value -ieq 'Task'
        }, $true)

    foreach ($command in $commands) {
        $nameElement = $command.CommandElements[1]
        if ($nameElement -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) {
            continue
        }
        $taskName = $nameElement.Value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($taskName) -and ($taskNames -notcontains $taskName)) {
            $taskNames += $taskName
        }
    }

    # ─── Follow psake `Include` directives so tasks defined in partial files
    # are discoverable too. Without this, splitting a large psakefile across
    # several files (for example, an environment psakefile that includes
    # app-psakefile.ps1 and site-psakefile.ps1) silently hides those tasks
    # from `jax run -only <TaskName>` even though psake itself loads them.
    #
    # Resolution covers common psakefile patterns:
    #
    #   Include "../common/psakefile.ps1"                  (string literal)
    #   Include "$PSScriptRoot/tasks-engine-switch.ps1"    (expandable string)
    #   Include "$gitRoot/code/...."                       (expandable string,
    #                                                       var bound earlier
    #                                                       in this file)
    #   Include (Join-Path $PSScriptRoot "file.ps1")
    #   Include (Join-Path $gitRoot "code/.../psakefile.ps1")
    #
    # `$PSScriptRoot` is the directory of this script. Other variables are
    # resolved by walking the top-level assignments in the same file and
    # statically evaluating the simple Join-Path / string-literal expressions
    # the existing scripts use. Anything more dynamic falls through and is
    # silently skipped — same fallback as before.
    $fileDir = Split-Path -Parent $FilePath
    $varScope = @{ PSScriptRoot = $fileDir }
    $assignments = $scriptAst.FindAll({
            param($ast)
            $ast -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $ast.Operator -eq 'Equals' -and
            $ast.Left -is [System.Management.Automation.Language.VariableExpressionAst]
        }, $false)
    $resolveExpr = $null
    $resolveExpr = {
        param($expr)
        if ($null -eq $expr) { return $null }
        if ($expr -is [System.Management.Automation.Language.CommandExpressionAst]) {
            return & $resolveExpr $expr.Expression
        }
        if ($expr -is [System.Management.Automation.Language.PipelineAst]) {
            if ($expr.PipelineElements.Count -ne 1) { return $null }
            return & $resolveExpr $expr.PipelineElements[0]
        }
        if ($expr -is [System.Management.Automation.Language.ParenExpressionAst]) {
            return & $resolveExpr $expr.Pipeline
        }
        if ($expr -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            return $expr.Value
        }
        if ($expr -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
            $result = $expr.Value
            foreach ($nested in @($expr.NestedExpressions)) {
                if ($nested -is [System.Management.Automation.Language.VariableExpressionAst]) {
                    $varName = $nested.VariablePath.UserPath
                    if ($varScope.ContainsKey($varName)) {
                        $result = $result -replace [regex]::Escape("`$$varName"), [string]$varScope[$varName]
                    } else {
                        return $null
                    }
                } else {
                    return $null
                }
            }
            return $result
        }
        if ($expr -is [System.Management.Automation.Language.VariableExpressionAst]) {
            $name = $expr.VariablePath.UserPath
            if ($varScope.ContainsKey($name)) { return [string]$varScope[$name] }
            return $null
        }
        if ($expr -is [System.Management.Automation.Language.CommandAst] -and
            $expr.CommandElements.Count -ge 3 -and
            $expr.CommandElements[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
            $expr.CommandElements[0].Value -ieq 'Join-Path') {
            $base = & $resolveExpr $expr.CommandElements[1]
            $tail = & $resolveExpr $expr.CommandElements[2]
            if ([string]::IsNullOrWhiteSpace($base) -or [string]::IsNullOrWhiteSpace($tail)) {
                return $null
            }
            return Join-Path $base $tail
        }
        return $null
    }
    foreach ($assignment in $assignments) {
        $name = $assignment.Left.VariablePath.UserPath
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($varScope.ContainsKey($name)) { continue }
        $value = & $resolveExpr $assignment.Right
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $varScope[$name] = $value
        }
    }

    $includeCommands = $scriptAst.FindAll({
            param($ast)
            $ast -is [System.Management.Automation.Language.CommandAst] -and
            $ast.CommandElements.Count -gt 1 -and
            $ast.CommandElements[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
            $ast.CommandElements[0].Value -ieq 'Include'
        }, $true)

    foreach ($command in $includeCommands) {
        $arg = $command.CommandElements[1]
        $includePath = & $resolveExpr $arg

        if ([string]::IsNullOrWhiteSpace($includePath)) {
            # Unresolvable Include (dynamic variable, computed path). Skip
            # silently — the task definitions in that file just won't be
            # discoverable via parsing.
            continue
        }

        if (-not [System.IO.Path]::IsPathRooted($includePath)) {
            $includePath = Join-Path $fileDir $includePath
        }
        try {
            $includePath = [System.IO.Path]::GetFullPath($includePath)
        } catch {
            # Leave path as-is; Test-Path inside the recursive call will reject
            # it if invalid.
        }

        $recursed = Get-JaxPsakeTaskInfoByParsing -FilePath $includePath -NoCache:$NoCache -VisitedFiles $VisitedFiles
        foreach ($name in $recursed.TaskNames) {
            if (-not [string]::IsNullOrWhiteSpace($name) -and ($taskNames -notcontains $name)) {
                $taskNames += $name
            }
        }
    }

    $parameters = @()
    $propertiesMatch = [regex]::Match($contentRaw, '(?ms)properties\s*\{(.*?)\}')
    if ($propertiesMatch.Success) {
        $block = $propertiesMatch.Groups[1].Value
        $lines = $block -split "(\r\n|\n)"
        foreach ($line in $lines) {
            $trimmed = ($line -replace '#.*$', '').Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) {
                continue
            }
            $paramMatch = [regex]::Match($trimmed, '^\s*(?:\[(?<type>[^\]]+)\])?\s*\$(?<name>[\w-]+)\s*(?:=\s*(?<default>.+?))?\s*(?:,)?$')
            if (-not $paramMatch.Success) {
                continue
            }
            $paramName = $paramMatch.Groups['name'].Value
            if ([string]::IsNullOrWhiteSpace($paramName)) {
                continue
            }
            $typeName = if ($paramMatch.Groups['type'].Success) { $paramMatch.Groups['type'].Value.Trim() } else { 'System.Object' }
            $defaultValue = $null
            if ($paramMatch.Groups['default'].Success) {
                $rawValue = $paramMatch.Groups['default'].Value.Trim().TrimEnd(',')
                if ($rawValue -match "^'.*'$" -or $rawValue -match '^".*"$') {
                    $rawValue = $rawValue.Trim("'").Trim('"')
                }
                switch ($rawValue.ToLower()) {
                    '$true' { $defaultValue = $true }
                    '$false' { $defaultValue = $false }
                    '$null' { $defaultValue = $null }
                    default { $defaultValue = $rawValue }
                }
            }
            $parameters += [ordered]@{
                Name         = $paramName
                Type         = $typeName
                Description  = "$paramName set in '$FilePath' properties block"
                DefaultValue = $defaultValue
            }
        }
    }

    return @{
        TaskNames  = $taskNames
        Parameters = $parameters
    }
}
