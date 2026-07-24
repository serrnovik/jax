function Update-JaxVaultRepoConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [string] $VaultAddress,
        [string] $TokenDir,
        [string] $Policy,
        [string] $TokenTtl
    )

    $commonParams = Get-JaxCommonParameters -BoundParameters $PSBoundParameters

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Get-JaxRepoRoot @commonParams
    }
    $repoRootResolved = (Resolve-Path -Path $RepoRoot).Path

    $configDir = Join-Path $repoRootResolved '.jax'
    if (-not (Test-Path -Path $configDir -PathType Container)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $configPath = Join-Path $configDir 'jax.config.yml'

    # IMPORTANT: avoid full YAML re-serialization here; it can reorder keys and can corrupt emojis/comments.
    # We'll do a minimal in-file update of only the vault-related lines and plugin enablement.

    $lines = @()
    $raw = $null
    $configWasMissing = -not (Test-Path -Path $configPath -PathType Leaf)
    if (-not $configWasMissing) {
        $raw = Get-Content -Path $configPath -Raw -ErrorAction Stop
        # Split on newlines robustly (regex), preserving indentation and avoiding accidental "single-line" parses.
        $lines = @($raw -split '\r?\n')
    } else {
        $lines = @(
            'jax:',
            '  plugins:',
            '    enabled: []',
            '    disabled: []',
            '    paths: []',
            '    config:',
            '      vault:',
            '        enabled: true'
        )
    }

    function Normalize-TokenDirValue {
        param([string] $value)
        if ([string]::IsNullOrWhiteSpace($value)) { return $null }
        $v = $value.Trim()
        $hasSeparators = $v.Contains('/') -or $v.Contains('\\')
        $looksLikeRelative = $v.StartsWith('.')
        if (-not $hasSeparators -and -not $looksLikeRelative -and -not [System.IO.Path]::IsPathRooted($v)) {
            # Shorthand like 'project-key' becomes '.jax/project-key/vault'.
            return (Join-Path '.jax' (Join-Path $v 'vault'))
        }
        return $v
    }

    function Normalize-TokenTtlValue {
        param([string] $value)
        if ([string]::IsNullOrWhiteSpace($value)) { return $null }
        $v = $value.Trim()
        if ($v -match '^\d+$') {
            # allow shorthand "87600" meaning hours -> "87600h"
            return "${v}h"
        }
        return $v
    }

    $TokenDir = Normalize-TokenDirValue $TokenDir
    $TokenTtl = Normalize-TokenTtlValue $TokenTtl
    if (-not [string]::IsNullOrWhiteSpace($VaultAddress)) {
        $VaultAddress = $VaultAddress.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($Policy)) {
        $Policy = $Policy.Trim()
    }

    # Also support manually minimized or older `jax: {}` repositories. Expand
    # only the plugin contract required for Vault, not every internal default.
    if ($configWasMissing -or $raw -match '^\s*jax\s*:\s*\{\s*\}\s*$') {
        $effectiveConfig = Get-JaxConfig -RepoRoot $repoRootResolved
        $enabledPlugins = @($effectiveConfig.plugins.enabled)
        if ($enabledPlugins -notcontains 'vault') {
            $enabledPlugins += 'vault'
        }
        $disabledPlugins = @($effectiveConfig.plugins.disabled | Where-Object { $_ -ne 'vault' })

        $vaultConfig = [ordered]@{ enabled = $true }
        if (-not [string]::IsNullOrWhiteSpace($VaultAddress)) { $vaultConfig['address'] = $VaultAddress }
        if (-not [string]::IsNullOrWhiteSpace($TokenDir)) { $vaultConfig['tokenDir'] = $TokenDir }
        if (-not [string]::IsNullOrWhiteSpace($Policy)) { $vaultConfig['policy'] = $Policy }
        if (-not [string]::IsNullOrWhiteSpace($TokenTtl)) { $vaultConfig['tokenTtl'] = $TokenTtl }

        $payload = [ordered]@{
            jax = [ordered]@{
                plugins = [ordered]@{
                    enabled  = $enabledPlugins
                    disabled = $disabledPlugins
                    config   = [ordered]@{
                        vault = $vaultConfig
                    }
                }
            }
        }
        Write-JaxYaml -Path $configPath -InputObject $payload
        return $configPath
    }

    function Remove-DuplicateMapKeysInBlock {
        param(
            [string[]] $inputLines,
            [int] $startIdx,
            [int] $baseIndent
        )
        $seen = @{}
        $out = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $inputLines.Count; $i++) { $out.Add($inputLines[$i]) | Out-Null }

        $i = $startIdx + 1
        while ($i -lt $out.Count) {
            $line = $out[$i]
            if ($null -eq $line) { $i++; continue }
            if ($line.Trim().Length -eq 0) { $i++; continue }
            $indent = ($line -replace '^(\s*).+$', '$1').Length
            if ($indent -le $baseIndent) { break }

            # match "key: value" at next indent level
            $trimmed = $line.Trim()
            if ($trimmed -match '^([A-Za-z0-9_\\-]+)\\s*:') {
                $k = $Matches[1]
                if ($seen.ContainsKey($k)) {
                    $out.RemoveAt($i)
                    continue
                }
                $seen[$k] = $true
            }
            $i++
        }
        return ,$out
    }

    # If file already got corrupted with duplicate icon keys, fix it (keep first occurrence).
    for ($idx = 0; $idx -lt $lines.Count; $idx++) {
        $l = $lines[$idx]
        if ($l -match '^\s{4}clientIcons:\s*$') {
            $lines = Remove-DuplicateMapKeysInBlock -inputLines $lines -startIdx $idx -baseIndent 4
        }
        if ($l -match '^\s{4}flowIcons:\s*$') {
            $lines = Remove-DuplicateMapKeysInBlock -inputLines $lines -startIdx $idx -baseIndent 4
        }
    }

    # Enable vault plugin in plugins.enabled / remove from plugins.disabled
    function Ensure-ListContainsItem {
        param(
            [System.Collections.Generic.List[string]] $list,
            [int] $blockStartIdx,
            [int] $keyIndent,
            [string] $item
        )
        $itemLine = (' ' * ($keyIndent + 2)) + "- $item"
        $i = $blockStartIdx + 1
        $found = $false
        while ($i -lt $list.Count) {
            $line = $list[$i]
            $indent = ($line -replace '^(\s*).+$', '$1').Length
            if ($indent -le $keyIndent) { break }
            if ($line.Trim() -eq "- $item") { $found = $true }
            $i++
        }
        if (-not $found) {
            $list.Insert($i, $itemLine)
        }
    }

    function Remove-ItemFromListBlock {
        param(
            [System.Collections.Generic.List[string]] $list,
            [int] $blockStartIdx,
            [int] $keyIndent,
            [string] $item
        )
        $i = $blockStartIdx + 1
        while ($i -lt $list.Count) {
            $line = $list[$i]
            $indent = ($line -replace '^(\s*).+$', '$1').Length
            if ($indent -le $keyIndent) { break }
            if ($line.Trim() -eq "- $item") {
                $list.RemoveAt($i)
                continue
            }
            $i++
        }
    }

    $listLines = New-Object System.Collections.Generic.List[string]
    foreach ($l in $lines) { $listLines.Add($l) | Out-Null }

    $enabledIdx = -1
    $disabledIdx = -1
    for ($i = 0; $i -lt $listLines.Count; $i++) {
        if ($listLines[$i] -match '^\s{4}enabled:\s*$') { $enabledIdx = $i }
        if ($listLines[$i] -match '^\s{4}disabled:\s*$') { $disabledIdx = $i }
    }
    if ($enabledIdx -ge 0) { Ensure-ListContainsItem -list $listLines -blockStartIdx $enabledIdx -keyIndent 4 -item 'vault' }
    if ($disabledIdx -ge 0) { Remove-ItemFromListBlock -list $listLines -blockStartIdx $disabledIdx -keyIndent 4 -item 'vault' }

    # Update vault config block (jax.plugins.config.vault)
    $vaultIdx = -1
    for ($i = 0; $i -lt $listLines.Count; $i++) {
        if ($listLines[$i] -match '^\s{6}vault:\s*$') { $vaultIdx = $i; break }
    }
    if ($vaultIdx -lt 0) {
        # insert vault block after "    config:" if present, else append a minimal block.
        $configIdx = -1
        for ($i = 0; $i -lt $listLines.Count; $i++) {
            if ($listLines[$i] -match '^\s{4}config:\s*$') { $configIdx = $i; break }
        }
        if ($configIdx -ge 0) {
            $vaultIdx = $configIdx + 1
            $listLines.Insert($vaultIdx, '      vault:')
            $listLines.Insert($vaultIdx + 1, '        enabled: true')
        } else {
            $vaultIdx = $listLines.Count
            $listLines.Add('  plugins:') | Out-Null
            $listLines.Add('    enabled:') | Out-Null
            $listLines.Add('      - vault') | Out-Null
            $listLines.Add('    config:') | Out-Null
            $listLines.Add('      vault:') | Out-Null
            $listLines.Add('        enabled: true') | Out-Null
        }
    }

    # Ensure enabled:true + address/tokenDir lines exist in vault block.
    $vaultBlockEnd = $vaultIdx + 1
    while ($vaultBlockEnd -lt $listLines.Count) {
        $line = $listLines[$vaultBlockEnd]
        $indent = ($line -replace '^(\s*).+$', '$1').Length
        if ($indent -le 6) { break }
        $vaultBlockEnd++
    }

    $hasEnabledLine = $false
    $hasAddressLine = $false
    $hasTokenDirLine = $false
    $hasPolicyLine = $false
    $hasTokenTtlLine = $false
    for ($i = $vaultIdx + 1; $i -lt $vaultBlockEnd; $i++) {
        $trimmed = $listLines[$i].Trim()
        if ($trimmed -match '^enabled\s*:') { $hasEnabledLine = $true; $listLines[$i] = '        enabled: true' }
        if ($trimmed -match '^address\s*:') { $hasAddressLine = $true; if (-not [string]::IsNullOrWhiteSpace($VaultAddress)) { $listLines[$i] = "        address: $VaultAddress" } }
        if ($trimmed -match '^tokenDir\s*:') { $hasTokenDirLine = $true; if (-not [string]::IsNullOrWhiteSpace($TokenDir)) { $listLines[$i] = "        tokenDir: $TokenDir" } }
        if ($trimmed -match '^policy\s*:') { $hasPolicyLine = $true; if (-not [string]::IsNullOrWhiteSpace($Policy)) { $listLines[$i] = "        policy: $Policy" } }
        if ($trimmed -match '^tokenTtl\s*:') { $hasTokenTtlLine = $true; if (-not [string]::IsNullOrWhiteSpace($TokenTtl)) { $listLines[$i] = "        tokenTtl: $TokenTtl" } }
    }
    $insertAt = $vaultIdx + 1
    if (-not $hasEnabledLine) { $listLines.Insert($insertAt, '        enabled: true'); $insertAt++ }
    if (-not $hasAddressLine -and -not [string]::IsNullOrWhiteSpace($VaultAddress)) { $listLines.Insert($insertAt, "        address: $VaultAddress"); $insertAt++ }
    if (-not $hasTokenDirLine -and -not [string]::IsNullOrWhiteSpace($TokenDir)) { $listLines.Insert($insertAt, "        tokenDir: $TokenDir"); $insertAt++ }
    if (-not $hasPolicyLine -and -not [string]::IsNullOrWhiteSpace($Policy)) { $listLines.Insert($insertAt, "        policy: $Policy"); $insertAt++ }
    if (-not $hasTokenTtlLine -and -not [string]::IsNullOrWhiteSpace($TokenTtl)) { $listLines.Insert($insertAt, "        tokenTtl: $TokenTtl"); $insertAt++ }

    # write back
    $outText = ($listLines -join "`n").TrimEnd() + "`n"
    Set-Content -Path $configPath -Value $outText -Encoding utf8
    return $configPath
}
