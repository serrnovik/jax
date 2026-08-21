function Get-JaxEntityDeclaredParameterNames {
    <#
    .SYNOPSIS
    The parameter names a single run entity declares for itself.

    .DESCRIPTION
    Psake entities carry them on Definition.Parameters (parsed out of the
    properties{} blocks); script entities declare them in their param() block and
    are read back through Get-Command. Both are best effort: an unreadable script
    contributes nothing rather than failing the run.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Entity,
        [hashtable] $Context = @{},
        [hashtable] $CommonParameters = @{}
    )

    $names = @()

    if ($Entity.Contains('Definition') -and $Entity['Definition'] -is [System.Collections.IDictionary]) {
        $definition = $Entity['Definition']
        if ($definition.Contains('Parameters') -and $definition['Parameters'] -is [System.Collections.IEnumerable]) {
            foreach ($parameter in @($definition['Parameters'])) {
                if ($parameter -isnot [System.Collections.IDictionary]) { continue }
                $name = [string]$parameter['Name']
                if ([string]::IsNullOrWhiteSpace($name)) { continue }
                $names += $name
            }
        }
    }

    if ($names.Count -gt 0) {
        return $names
    }

    if (-not ($Entity.Contains('Script') -and $Entity['Script'] -is [string])) {
        return $names
    }
    if ([string]::IsNullOrWhiteSpace($Entity['Script'])) {
        return $names
    }

    try {
        $scriptPath = Resolve-JaxRepoRootedPath -Path $Entity['Script'] -RepoRoot $Context['RepoRoot'] -WorkingDir $Context['WorkingDir'] @CommonParameters
        if ([string]::IsNullOrWhiteSpace($scriptPath)) { return $names }
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { return $names }
        $command = Get-Command -Name $scriptPath -ErrorAction SilentlyContinue
        if ($null -eq $command -or $null -eq $command.Parameters) { return $names }
        foreach ($entry in $command.Parameters.GetEnumerator()) {
            $name = [string]$entry.Key
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            $names += $name
        }
    } catch {
        # Best effort: a script Jax cannot read simply reports no parameters.
    }

    return $names
}
