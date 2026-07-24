function Set-JaxDiscoveredEntityDefaults {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Entity,
        [hashtable] $Context
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters
    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($PSBoundParameters | ConvertTo-Json -Depth 1 -Compress -WarningAction SilentlyContinue)"

    if ($null -eq $Context -or -not $Context.ContainsKey('DiscoveredEntityIndex')) {
        return $Entity
    }

    $index = $Context['DiscoveredEntityIndex']
    if ($index -isnot [System.Collections.IDictionary]) {
        return $Entity
    }

    $taskName = $null
    if ($Entity.Contains('Tasks') -and $null -ne $Entity['Tasks']) {
        $tasks = @($Entity['Tasks'])
        if ($tasks.Count -gt 0) {
            $taskName = $tasks[0]
        }
    }

    # If no explicit tasks: for script runners we often have Key != Script name (e.g. suite.library keys).
    if ([string]::IsNullOrWhiteSpace($taskName)) {
        if ($Entity.Contains('Script') -and $Entity['Script'] -is [string] -and -not [string]::IsNullOrWhiteSpace($Entity['Script'])) {
            $scriptKey = [string]$Entity['Script']
            $scriptKeyTrimmed = $scriptKey.Trim()
            $hasSeparators = $scriptKeyTrimmed.Contains('/') -or $scriptKeyTrimmed.Contains('\')
            $extension = [IO.Path]::GetExtension($scriptKeyTrimmed)
            if (-not $hasSeparators -and [string]::IsNullOrWhiteSpace($extension)) {
                $taskName = $scriptKeyTrimmed
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($taskName)) {
        $taskName = Get-JaxRunEntityKey -Entity $Entity @commonParams
    }
    if ([string]::IsNullOrWhiteSpace($taskName)) {
        return $Entity
    }

    $lookupKey = Convert-JaxRunEntityName -Name $taskName @commonParams
    if (-not $index.ContainsKey($lookupKey)) {
        return $Entity
    }

    $discovered = $index[$lookupKey]
    if ($discovered -isnot [System.Collections.IDictionary]) {
        return $Entity
    }

    if ($Entity.Contains('Runner')) {
        $runner = $Entity['Runner']
        if ($runner -eq 'psake' -and [string]::IsNullOrWhiteSpace($Entity['PsakeFile'])) {
            $Entity['PsakeFile'] = $discovered['PsakeFile']
        }
        if (($runner -eq 'pwshscript' -or $runner -eq 'bashscript' -or $runner -eq 'cmdscript') -and
            $Entity.Contains('Script') -and $Entity['Script'] -is [string] -and -not [string]::IsNullOrWhiteSpace($Entity['Script'])) {
            if (Test-JaxDictionaryHasKey -Dictionary $discovered -Key 'Script' @commonParams) {
                $Entity['Script'] = $discovered['Script']
            }
        }
    }

    if ($Entity.Contains('Tasks') -and ($null -eq $Entity['Tasks'] -or @($Entity['Tasks']).Count -eq 0)) {
        if (Test-JaxDictionaryHasKey -Dictionary $discovered -Key 'Tasks' @commonParams) {
            $Entity['Tasks'] = $discovered['Tasks']
        }
    }

    if (-not $Entity.Contains('Aliases') -and (Test-JaxDictionaryHasKey -Dictionary $discovered -Key 'Aliases' @commonParams)) {
        $Entity['Aliases'] = $discovered['Aliases']
    }
    if (-not $Entity.Contains('Definition') -and (Test-JaxDictionaryHasKey -Dictionary $discovered -Key 'Definition' @commonParams)) {
        $Entity['Definition'] = $discovered['Definition']
    }
    if (-not $Entity.Contains('DirectoryType') -and (Test-JaxDictionaryHasKey -Dictionary $discovered -Key 'DirectoryType')) {
        $Entity['DirectoryType'] = $discovered['DirectoryType']
    }

    if (-not $Entity.Contains('SourcePath') -and (Test-JaxDictionaryHasKey -Dictionary $discovered -Key 'SourcePath')) {
        $Entity['SourcePath'] = $discovered['SourcePath']
    }

    if (-not $Entity.Contains('Provenance') -and (Test-JaxDictionaryHasKey -Dictionary $discovered -Key 'Provenance')) {
        $Entity['Provenance'] = $discovered['Provenance']
    }

    return $Entity
}
