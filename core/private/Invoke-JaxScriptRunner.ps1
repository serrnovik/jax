function Invoke-JaxScriptRunner {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Entity,
        [hashtable] $Context = @{},
        [hashtable] $CommonParameters = @{}
    )

    Write-Debug "FUNC: $($MyInvocation.MyCommand.Name) Args: $($Entity['Key']) Script=$($Entity['Script'])"

    $scriptPath = $Entity['Script']
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        throw "Script runner requires 'Script' path."
    }

    $resolvedPath = Resolve-JaxRepoRootedPath -Path $scriptPath -RepoRoot $Context['RepoRoot'] -WorkingDir $Context['WorkingDir'] @CommonParameters
    $argsLine = Convert-JaxArgsToCommandLine -Args $Entity['Args'] @CommonParameters
    $command = "& `"$resolvedPath`" $argsLine"

    if ($Context['DryRun']) {
        if ($Context.ContainsKey('VaultSecretsResolved') -and [bool]$Context['VaultSecretsResolved']) {
            return "& `"$resolvedPath`" <arguments redacted>"
        }
        return $command.Trim()
    }

    Write-Host "🛸 Executing script: $resolvedPath"
    $args = $Entity['Args']
    if ($args -is [System.Collections.IDictionary]) {
        $argsHt = @{}
        foreach ($k in $args.Keys) {
            $argsHt[[string]$k] = $args[$k]
        }

        # CLI DynamicParam-bound script params: apply last (highest precedence)
        if ($Context.ContainsKey('CliArgs') -and $Context['CliArgs'] -is [System.Collections.IDictionary]) {
            foreach ($k in $Context['CliArgs'].Keys) {
                $argsHt[[string]$k] = $Context['CliArgs'][$k]
            }
        }

        # Filter out args not supported by the target script.
        # User requirement: extra CLI params should NOT error; they should be ignored.
        $cmdInfo = $null
        try {
            $cmdInfo = Get-Command -Name $resolvedPath -ErrorAction SilentlyContinue
        } catch {
            $cmdInfo = $null
        }
        if ($null -ne $cmdInfo -and $cmdInfo.Parameters) {
            $allowed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($p in $cmdInfo.Parameters.Keys) {
                $allowed.Add([string]$p) | Out-Null
            }
            foreach ($key in @($argsHt.Keys)) {
                if (-not $allowed.Contains([string]$key)) {
                    $argsHt.Remove($key) | Out-Null
                }
            }
        }

        # Do not promote args.verbose/args.debug into common parameters.
        # Verbose/debug should only be enabled by passing -Verbose/-Debug to jax itself.

        # Remove any args that collide with already-set common parameters (case-insensitive)
        foreach ($cpKey in @($CommonParameters.Keys)) {
            if ([string]::IsNullOrWhiteSpace($cpKey)) {
                continue
            }
            $lower = [string]$cpKey
            foreach ($ak in @($argsHt.Keys)) {
                if ($ak -and ($ak.ToLowerInvariant() -eq $lower.ToLowerInvariant())) {
                    $argsHt.Remove($ak) | Out-Null
                }
            }
        }

        return & $resolvedPath @argsHt @CommonParameters
    }
    if ($args -is [System.Collections.IEnumerable] -and $args -isnot [string]) {
        return & $resolvedPath @args @CommonParameters
    }

    return & $resolvedPath @CommonParameters
}
