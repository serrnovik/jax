function Write-JaxLogFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Content,
        [string] $Category = 'log',
        [string] $RepoRoot = (Get-JaxRepoRoot),
        [string] $Extension = 'log'
    )

    $logDir = Get-JaxLogDir -RepoRoot $RepoRoot
    if (-not (Test-Path -Path $logDir -PathType Container)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $safeCategory = $Category.Trim()
    if ([string]::IsNullOrWhiteSpace($safeCategory)) {
        $safeCategory = 'log'
    }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    $fileName = "{0}_{1}.{2}" -f $safeCategory, $stamp, $Extension
    $path = Join-Path $logDir $fileName

    Set-Content -Path $path -Value $Content -Encoding utf8
    return $path
}
