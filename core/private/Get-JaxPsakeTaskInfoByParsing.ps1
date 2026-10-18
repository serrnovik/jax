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
    if ($DebugPreference -ne 'SilentlyContinue') { Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)" }

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

    $parsed = Get-JaxPsakeFileParseInfo -FilePath $FilePath -NoCache:$NoCache @commonParams
    $taskNames = @($parsed.TaskNames)
    foreach ($includePath in @($parsed.IncludePaths)) {
        $recursed = Get-JaxPsakeTaskInfoByParsing -FilePath $includePath -NoCache:$NoCache -VisitedFiles $VisitedFiles
        foreach ($name in $recursed.TaskNames) {
            if (-not [string]::IsNullOrWhiteSpace($name) -and ($taskNames -notcontains $name)) {
                $taskNames += $name
            }
        }
    }

    return @{
        TaskNames  = $taskNames
        Parameters = @($parsed.Parameters)
    }
}
