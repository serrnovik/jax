function Get-JaxPsakeTaskDefinitions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $FilePath,
        [int] $MaxDepth = 10,
        [hashtable] $Visited = @{},
        [switch] $NoCache
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        return @()
    }

    if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
        return @()
    }

    if ($MaxDepth -le 0) {
        return @()
    }

    $fullPath = (Resolve-Path -Path $FilePath).Path
    $key = $fullPath.ToLowerInvariant()
    if ($Visited.ContainsKey($key)) {
        return @()
    }
    $Visited[$key] = $true

    $info = Get-JaxPsakeTaskInfoByParsing -FilePath $fullPath -NoCache:$NoCache @commonParams
    $definitions = @()
    foreach ($taskName in @($info.TaskNames)) {
        if ([string]::IsNullOrWhiteSpace($taskName)) {
            continue
        }
        $definitions += [ordered]@{
            Name       = $taskName
            FullPath   = $fullPath
            Parameters = @($info.Parameters)
            Values     = @()
        }
    }

    $includes = Get-JaxIncludedFiles -FilePath $fullPath @commonParams
    foreach ($include in $includes) {
        $definitions += Get-JaxPsakeTaskDefinitions -FilePath $include -MaxDepth ($MaxDepth - 1) -Visited $Visited -NoCache:$NoCache @commonParams
    }

    return $definitions
}
