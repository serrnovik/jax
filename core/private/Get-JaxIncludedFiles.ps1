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
        if ($argument -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) {
            continue
        }
        $path = $argument.Value
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
