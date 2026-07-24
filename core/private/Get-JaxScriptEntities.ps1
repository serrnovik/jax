function Get-JaxScriptEntities {
    [CmdletBinding()]
    param (
        [object[]] $DirPaths,
        [System.Collections.IDictionary] $AliasesMap,
        [switch] $NoCache
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    $entities = @()
    if ($null -eq $DirPaths -or $DirPaths.Count -eq 0) {
        return $entities
    }

    $extensions = @('.ps1', '.psm1', '.sh', '.bash', '.cmd', '.bat')

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

        $files = Get-ChildItem -Path $dirPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
            $extensions -contains $_.Extension.ToLowerInvariant()
        } | Sort-Object -Property FullName

        $dirEntities = @()
        foreach ($file in $files) {
            $name = [IO.Path]::GetFileNameWithoutExtension($file.Name)
            if ([string]::IsNullOrWhiteSpace($name)) {
                continue
            }
            $aliases = Resolve-JaxEntityAliases -Key $name -AliasesMap $AliasesMap -AdditionalAliases $null @commonParams
            $provenance = 'script'
            if (-not [string]::IsNullOrWhiteSpace($dirType)) {
                $provenance = "script -> $dirType"
            }
            $entity = [ordered]@{
                Key        = $name
                Runner     = Resolve-JaxScriptRunnerName -ScriptPath $file.FullName @commonParams
                Script     = $file.FullName
                Tasks      = @()
                Args       = $null
                PsakeFile  = $null
                Container  = $null
                Provenance = $provenance
                SourcePath = $file.FullName
                Aliases    = $aliases
                DirectoryType = $dirType
            }
            $dirEntities += $entity
        }
        if ($dirEntities.Count -gt 0) {
            $entities = Merge-JaxRunEntityList -Base $entities -Add $dirEntities @commonParams
        }
    }

    return $entities
}
