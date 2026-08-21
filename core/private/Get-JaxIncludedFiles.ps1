function Get-JaxIncludedFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $FilePath,
        [switch] $NoCache
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        return @()
    }

    $included = @()
    $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
    $parent = Split-Path -Parent $FilePath

    $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
    $commands = $scriptAst.FindAll({
            param($ast)
            $ast -is [System.Management.Automation.Language.CommandAst] -and
            $ast.CommandElements.Count -gt 1 -and
            $ast.CommandElements[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
            $ast.CommandElements[0].Value -ieq 'Include'
        }, $true)

    foreach ($command in $commands) {
        $argument = $command.CommandElements[1]
        $path = $null
        if ($argument -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $path = $argument.Value
        } elseif ($argument -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -and
                  $argument.Value -match '^\$PSScriptRoot[\\/]') {
            # `Include "$PSScriptRoot/tasks-x.ps1"` is the CORRECT way to write
            # an include — psake's own Include resolves a bare relative path
            # against the CURRENT DIRECTORY, so a literal breaks the moment a
            # nested env (env/<app>) includes a shared psakefile from
            # env/common. Skipping expandable strings meant discovery followed
            # only literals, so eight of the nine includes in env/common were
            # invisible here and their task parameters never reached the CLI.
            # Someone then wrote one include as a literal to make discovery see
            # it, which broke every nested env at runtime instead.
            #
            # $PSScriptRoot inside a script IS that script's directory, which is
            # exactly $parent, so this is a substitution rather than an eval.
            $path = $argument.Value -replace '^\$PSScriptRoot', $parent
        }
        if ($null -eq $path) {
            continue
        }
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }
        if (-not [System.IO.Path]::IsPathRooted($path)) {
            $path = Join-Path $parent $path
        }
        $path = [IO.Path]::GetFullPath($path)
        if ($included -notcontains $path) {
            $included += $path
        }
    }

    return $included
}
