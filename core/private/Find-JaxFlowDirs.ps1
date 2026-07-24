function Find-JaxFlowDirs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $EnvRootPath,
        [Parameter(Mandatory = $true)]
        [string[]] $FlowDirNames,
        [hashtable] $CommonParameters = @{}
    )

    $results = @()
    $flowDirSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $FlowDirNames) {
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $flowDirSet.Add($name) | Out-Null
        }
    }

    $useFind = $false
    if (($IsLinux -or $IsMacOS) -and (Get-Command -Name find -ErrorAction SilentlyContinue)) {
        $useFind = $true
    }

    if ($useFind) {
        foreach ($dirName in $flowDirSet) {
            $paths = & find $EnvRootPath -type d -name $dirName 2>$null
            foreach ($path in $paths) {
                if ([string]::IsNullOrWhiteSpace($path)) { continue }
                try {
                    $results += Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
                } catch {
                }
            }
        }
        return $results | Where-Object { $_ -ne $null }
    }

    return Get-ChildItem -Path $EnvRootPath -Recurse -Directory -ErrorAction SilentlyContinue @CommonParameters |
        Where-Object { $flowDirSet.Contains($_.Name) }
}
