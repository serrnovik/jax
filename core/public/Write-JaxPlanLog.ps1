function Write-JaxPlanLog {
    [CmdletBinding()]
    param (
        [object[]] $Entities,
        [string] $RepoRoot = (Get-JaxRepoRoot)
    )

    $entries = @()
    $entries += "Jax Run Plan"
    $entries += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $entries += ""

    if ($null -ne $Entities) {
        foreach ($entity in $Entities) {
            $entries += "----"
            $entries += (Format-JaxRunEntityLog -Entity $entity)
        }
    }

    $content = $entries -join [Environment]::NewLine
    return Write-JaxLogFile -Content $content -Category 'plan' -RepoRoot $RepoRoot
}
