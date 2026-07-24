function Resolve-JaxBobLayerFiles {
    [CmdletBinding()]
    param (
        [string[]] $Patterns,
        [string] $RepoRoot
    )

    if ($null -eq $Patterns -or $Patterns.Count -eq 0) {
        return @()
    }

    $files = @()
    foreach ($pattern in $Patterns) {
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            continue
        }
        $resolved = Resolve-JaxRunConfigPath -Path $pattern -RepoRoot $RepoRoot -BaseDir $RepoRoot
        $files += Get-ChildItem -Path $resolved -File -ErrorAction SilentlyContinue
    }

    return @($files | Sort-Object -Property FullName -Unique | ForEach-Object { $_.FullName })
}
