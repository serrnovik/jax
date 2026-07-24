function Resolve-JaxEnvDirFromFlowPath {
    [CmdletBinding()]
    param (
        [string] $FlowConfigPath,
        [System.Collections.IDictionary] $Config,
        [string] $RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($FlowConfigPath)) {
        return $null
    }

    $flowDir = Split-Path -Path $FlowConfigPath -Parent
    if ([string]::IsNullOrWhiteSpace($flowDir)) {
        return $null
    }

    if ($null -eq $Config) {
        $Config = Get-JaxConfig -RepoRoot $RepoRoot
    }

    $flowDirName = Split-Path -Path $flowDir -Leaf
    if ($Config.Keys -contains 'flowDirNames' -and $Config['flowDirNames'] -contains $flowDirName) {
        return (Split-Path -Path $flowDir -Parent)
    }

    return $null
}
