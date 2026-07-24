function Get-JaxPsakeTaskEntities {
    [CmdletBinding()]
    param (
        [object[]] $DirPaths,
        [string] $FilePattern,
        [string[]] $TaskIgnoreList,
        [System.Collections.IDictionary] $AliasesMap,
        [switch] $NoCache
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    Initialize-JaxPsakeProvider @commonParams

    $entities = @()
    if ($null -eq $DirPaths -or $DirPaths.Count -eq 0) {
        return $entities
    }

    $ignoreSet = @()
    if ($TaskIgnoreList) {
        $ignoreSet = @($TaskIgnoreList | ForEach-Object { $_.ToString().Trim().ToLowerInvariant() } | Where-Object { $_ -ne '' })
    }

    foreach ($dir in $DirPaths) {
        $dirPath = $dir
        $dirType = $null
        if ($dir -is [System.Collections.IDictionary]) {
            if ($dir.Contains('Path')) {
                $dirPath = $dir['Path']
            }
            if ($dir.Contains('DirectoryType')) {
                $dirType = $dir['DirectoryType']
            }
        }
        if ([string]::IsNullOrWhiteSpace($dirPath)) {
            continue
        }
        if (-not (Test-Path -Path $dirPath -PathType Container)) {
            continue
        }

        $pattern = $FilePattern
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            $pattern = 'psakefile*.ps1'
        }

        $files = Get-ChildItem -Path $dirPath -Filter $pattern -File -ErrorAction SilentlyContinue | Sort-Object -Property FullName
        $dirEntities = @()
        foreach ($file in $files) {
            $fileEntities = @()
            $definitions = Get-JaxPsakeTaskDefinitions -FilePath $file.FullName -NoCache:$NoCache @commonParams
            foreach ($definition in $definitions) {
                $taskName = $definition['Name']
                if ([string]::IsNullOrWhiteSpace($taskName)) {
                    continue
                }
                if ($ignoreSet -contains $taskName.ToLowerInvariant()) {
                    continue
                }

                $aliases = Resolve-JaxEntityAliases -Key $taskName -AliasesMap $AliasesMap -AdditionalAliases $null @commonParams
                $provenance = 'psake'
                if (-not [string]::IsNullOrWhiteSpace($dirType)) {
                    $provenance = "psake -> $dirType"
                }
                $entity = [ordered]@{
                    Key        = $taskName
                    Runner     = 'psake'
                    Tasks      = @($taskName)
                    PsakeFile  = $definition['FullPath']
                    Args       = $null
                    Script     = $null
                    Container  = $null
                    Provenance = $provenance
                    SourcePath = $definition['FullPath']
                    Aliases    = $aliases
                    Definition = $definition
                    DirectoryType = $dirType
                }
                $fileEntities += $entity
            }
            if ($fileEntities.Count -gt 0) {
                $dirEntities = Merge-JaxRunEntityList -Base $dirEntities -Add $fileEntities @commonParams
            }
        }
        if ($dirEntities.Count -gt 0) {
            $entities = Merge-JaxRunEntityList -Base $entities -Add $dirEntities @commonParams
        }
    }

    return $entities
}
