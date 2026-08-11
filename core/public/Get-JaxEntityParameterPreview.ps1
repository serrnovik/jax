function Get-JaxEntityParameterPreview {
    <#
    .SYNOPSIS
    Resolves the parameters a run entity would actually receive, without running it.

    .DESCRIPTION
    Answers "what did my CLI flags actually do?" for dry runs. Each declared task or
    script parameter is reported with its effective value and where that value came
    from, plus any CLI parameter that is NOT declared by the entity (a typo, or a
    param meant for a different task) so it does not disappear silently.

    Values are passed through Convert-JaxToJsonSafeValue, so sensitive keys
    (password/secret/token/...) come back as '[redacted]'. Only parameters the entity
    itself declares are reported, so the run-config/secrets bag is never echoed.

    Source is one of:
      cli      - passed on the command line this run (highest precedence)
      args     - set by the flow file's `args:` for this entity
      config   - inherited from run-config / psake properties
      default  - the `properties{}` (or param()) default; nothing overrode it
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Entity,
        [hashtable] $Context = @{},
        [hashtable] $CommonParameters = @{}
    )

    $cliArgs = @{}
    if ($Context.ContainsKey('CliArgs') -and $Context['CliArgs'] -is [System.Collections.IDictionary]) {
        foreach ($k in $Context['CliArgs'].Keys) { $cliArgs[[string]$k] = $Context['CliArgs'][$k] }
    }
    $entityArgs = @{}
    if ($Entity['Args'] -is [System.Collections.IDictionary]) {
        foreach ($k in $Entity['Args'].Keys) { $entityArgs[[string]$k] = $Entity['Args'][$k] }
    }

    # Declared parameters, plus the effective (merged) values for this entity.
    $declared = [ordered]@{}
    $effective = @{}

    if ($Entity.Contains('Definition') -and $Entity['Definition'] -is [System.Collections.IDictionary]) {
        $definition = $Entity['Definition']
        if ($definition.Contains('Parameters') -and $definition['Parameters'] -is [System.Collections.IEnumerable]) {
            foreach ($p in @($definition['Parameters'])) {
                if ($p -isnot [System.Collections.IDictionary]) { continue }
                $pName = [string]$p['Name']
                if ([string]::IsNullOrWhiteSpace($pName)) { continue }
                if ($declared.Contains($pName)) { continue }
                $declared[$pName] = $p
            }
        }
    }

    if ($declared.Count -gt 0) {
        $effective = Resolve-JaxPsakeProperties -Entity $Entity -Context $Context -CommonParameters $CommonParameters
    } else {
        # Script entity: args + CLI overrides, filtered to the script's own param() block.
        $scriptPath = $null
        if ($Entity.Contains('Script') -and $Entity['Script'] -is [string] -and -not [string]::IsNullOrWhiteSpace($Entity['Script'])) {
            $scriptPath = Resolve-JaxRepoRootedPath -Path $Entity['Script'] -RepoRoot $Context['RepoRoot'] -WorkingDir $Context['WorkingDir'] @CommonParameters
        }
        if (-not [string]::IsNullOrWhiteSpace($scriptPath) -and (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            $cmdInfo = Get-Command -Name $scriptPath -ErrorAction SilentlyContinue
            if ($null -ne $cmdInfo -and $cmdInfo.Parameters) {
                foreach ($kv in $cmdInfo.Parameters.GetEnumerator()) {
                    $pName = [string]$kv.Key
                    if ([string]::IsNullOrWhiteSpace($pName)) { continue }
                    $declared[$pName] = @{ Name = $pName; Type = [string]$kv.Value.ParameterType.Name; DefaultValue = $null }
                }
            }
        }
        $effective = @{}
        foreach ($k in $entityArgs.Keys) { $effective[$k] = $entityArgs[$k] }
        foreach ($k in $cliArgs.Keys) { $effective[$k] = $cliArgs[$k] }
    }

    $rows = @()
    foreach ($pName in @($declared.Keys)) {
        $meta = $declared[$pName]

        $source = 'default'
        $value = $null
        if ($meta -is [System.Collections.IDictionary] -and $meta.Contains('DefaultValue')) {
            $value = $meta['DefaultValue']
        }

        if ($cliArgs.ContainsKey($pName)) {
            $source = 'cli'
            $value = $cliArgs[$pName]
        } elseif ($entityArgs.ContainsKey($pName)) {
            $source = 'args'
            $value = $entityArgs[$pName]
        } elseif ($effective -is [System.Collections.IDictionary] -and $effective.Contains($pName)) {
            $source = 'config'
            $value = $effective[$pName]
        }

        $type = ''
        if ($meta -is [System.Collections.IDictionary] -and $meta.Contains('Type')) { $type = [string]$meta['Type'] }

        $rows += [ordered]@{
            Name   = $pName
            Type   = $type
            Value  = (Convert-JaxToJsonSafeValue -Value $value -KeyName $pName @CommonParameters)
            Source = $source
        }
    }

    # Jax's own flags (-dryRun, -novault, plugin flags, -C/-RepoRoot) also travel in CliArgs.
    # They are not task parameters, so they stay out of the "not declared" list below.
    $jaxOwned = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @('RepoRoot', 'C')) { $jaxOwned.Add($name) | Out-Null }
    try {
        foreach ($def in @(Get-JaxCliParameters)) {
            if ($null -eq $def) { continue }
            if ($def.Name) { $jaxOwned.Add([string]$def.Name) | Out-Null }
            foreach ($alias in @($def.Aliases)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$alias)) { $jaxOwned.Add([string]$alias) | Out-Null }
            }
        }
    } catch {
        # Registry unavailable: fall back to reporting everything rather than hiding it.
    }

    # CLI params the entity does not declare: surfaced, never silently dropped.
    foreach ($k in @($cliArgs.Keys)) {
        if ($declared.Contains($k)) { continue }
        if ($jaxOwned.Contains([string]$k)) { continue }
        $rows += [ordered]@{
            Name   = $k
            Type   = ''
            Value  = (Convert-JaxToJsonSafeValue -Value $cliArgs[$k] -KeyName $k @CommonParameters)
            Source = 'cli (not declared by this entity)'
        }
    }

    return $rows
}
