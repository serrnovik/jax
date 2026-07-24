function Get-JaxTabTitleForRun {
    [CmdletBinding()]
    param(
        [string] $EntityKey,
        [object] $EnvName,
        [object] $FlowName,
        [string] $CurrentPsakeTask,
        [string] $Runner = 'psake'
    )

    $titleParts = @()

    # Normalize possibly-rich objects (hashtable, PSCustomObject, full env config, etc.)
    # coming from RunConfig, $properties, Context, etc. into clean strings.
    try {
        function Get-StringValue($value, [string[]]$preferredKeys = @('name', 'Name', 'displayName')) {
            if ($null -eq $value) { return '' }
            if ($value -is [string]) { return $value.Trim() }
            if ($value -is [System.Collections.IDictionary]) {
                foreach ($k in $preferredKeys) {
                    if ($value.Contains($k) -and -not [string]::IsNullOrWhiteSpace([string]$value[$k])) {
                        return ([string]$value[$k]).Trim()
                    }
                }
                # last resort: first string-ish value
                foreach ($v in $value.Values) {
                    if ($v -is [string] -and -not [string]::IsNullOrWhiteSpace($v)) { return $v.Trim() }
                }
            }
            if ($value.PSObject -and $value.PSObject.Properties) {
                foreach ($k in $preferredKeys) {
                    $p = $value.PSObject.Properties.Match($k)
                    if ($p.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$p[0].Value)) {
                        return ([string]$p[0].Value).Trim()
                    }
                }
            }
            $s = [string]$value
            if ($s -match 'System\.Collections') { return '' } # avoid ugly ToString() of dictionaries
            return $s.Trim()
        }

        $EnvName  = Get-StringValue $EnvName
        $FlowName = Get-StringValue $FlowName
    } catch {}

    try {
        $cfg = Get-JaxConfig -ErrorAction SilentlyContinue
        $auto = if ($cfg -and $cfg.Contains('autocomplete')) { $cfg['autocomplete'] } else { @{} }

        $clientIcons = if ($auto -and $auto.Contains('clientIcons')) { $auto['clientIcons'] } else { @{} }
        $flowIcons   = if ($auto -and $auto.Contains('flowIcons'))   { $auto['flowIcons'] }   else { @{} }

        # Defaults (same spirit as autocomplete completer)
        if (-not $clientIcons.Contains('build'))   { $clientIcons['build']   = '👷' }
        if (-not $clientIcons.Contains('generic')) { $clientIcons['generic'] = '🌐' }
        if (-not $clientIcons.Contains('none'))    { $clientIcons['none']    = '🚫' }
        if (-not $flowIcons.Contains('build'))     { $flowIcons['build']     = '🔨' }
        if (-not $flowIcons.Contains('play'))      { $flowIcons['play']      = '🧪' }
        if (-not $flowIcons.Contains('pack'))      { $flowIcons['pack']      = '📦' }

        $clientKey = if ($EnvName) { ($EnvName -split '/')[0] } else { '' }
        $clientIcon = if ($clientIcons.Contains($clientKey)) { $clientIcons[$clientKey] } else { '📁' }

        $flowKey = if ($FlowName) { $FlowName } else { '' }
        $flowIcon = if ($flowKey -and $flowIcons.Contains($flowKey)) { $flowIcons[$flowKey] } else { '🔨' }

        # Keep icon resolution above intact for now, but do not include the icon
        # pair in cmux tab titles. The compact env token is more scannable in
        # narrow pane tabs, and the icon logic can be re-enabled if wanted.
        $includeTitleIcons = $false
        $iconPair = if ($includeTitleIcons) { "$clientIcon $flowIcon".Trim() } else { '' }

        # Layout: [<env5…>] <task> [→ <currentTask>]
        # The env is shortened to a compact token (the flow stays as the emoji); the
        # state glyph (spinner / ✓ / ✗) is added later by Set-/Complete-JaxTerminalTitle.
        $envShort = Get-JaxShortEnvToken -EnvName $EnvName -FlowName $FlowName

        if ($iconPair) {
            $titleParts += $iconPair
        }

        if ($envShort) {
            $titleParts += "[$envShort]"
        }

        if ($EntityKey) {
            $titleParts += $EntityKey
        } elseif ($CurrentPsakeTask) {
            $titleParts += $CurrentPsakeTask
        }

        if ($CurrentPsakeTask -and $EntityKey -and ($CurrentPsakeTask -ne $EntityKey)) {
            $titleParts += "→ $CurrentPsakeTask"
        }
    }
    catch {
        # Fallback to something useful even if config/icons blew up
        if ($EnvName -or $FlowName) {
            $envShort = Get-JaxShortEnvToken -EnvName $EnvName -FlowName $FlowName
            $titleParts = @()
            if ($envShort) { $titleParts += "[$envShort]" }
            if ($EntityKey) { $titleParts += $EntityKey }
            if ($CurrentPsakeTask -and $CurrentPsakeTask -ne $EntityKey) {
                $titleParts += "→ $CurrentPsakeTask"
            }
        }
        else {
            $titleParts = @($EntityKey)
        }
    }

    $title = ($titleParts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' '
    return $title.Trim()
}
