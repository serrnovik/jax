function Resolve-JaxCliCommand {
    [CmdletBinding()]
    param (
        [string] $Command,
        [string[]] $CommandArgs
    )

    $tokens = @()
    if ($null -ne $Command) {
        $tokens += $Command
    }
    if ($null -ne $CommandArgs) {
        $tokens += $CommandArgs
    }

    if ($tokens.Count -eq 0) {
        return @{
            Command = $null
            Args    = @()
        }
    }

    $definitions = Get-JaxCliParameters
    $lookup = @{}
    foreach ($definition in $definitions) {
        $lookup[$definition.Name.ToLowerInvariant()] = $definition
        foreach ($alias in $definition.Aliases) {
            $lookup[$alias.ToLowerInvariant()] = $definition
        }
    }

    $commandIndex = $null
    $index = 0
    while ($index -lt $tokens.Count) {
        $token = $tokens[$index]
        if ($token.StartsWith('-')) {
            $name = $token.TrimStart('-')
            $valueInline = $null
            if ($name.Contains('=')) {
                $parts = $name.Split('=', 2)
                $name = $parts[0]
                $valueInline = $parts[1]
            }

            $normalized = $name.ToLowerInvariant()
            if ($lookup.ContainsKey($normalized)) {
                $definition = $lookup[$normalized]
                if ($definition.Type -ne 'switch' -and $null -eq $valueInline -and ($index + 1) -lt $tokens.Count) {
                    $next = $tokens[$index + 1]
                    if (-not $next.StartsWith('-')) {
                        $index += 2
                        continue
                    }
                }
            } elseif ($null -eq $valueInline -and ($index + 1) -lt $tokens.Count) {
                $next = $tokens[$index + 1]
                if (-not $next.StartsWith('-')) {
                    $index += 2
                    continue
                }
            }

            $index++
            continue
        }

        $commandIndex = $index
        break
    }

    if ($null -eq $commandIndex) {
        return @{
            Command = $tokens[0]
            Args    = if ($tokens.Count -gt 1) { @($tokens[1..($tokens.Count - 1)]) } else { @() }
        }
    }

    $args = @()
    if ($commandIndex -gt 0) {
        $args += $tokens[0..($commandIndex - 1)]
    }
    if (($commandIndex + 1) -lt $tokens.Count) {
        $args += $tokens[($commandIndex + 1)..($tokens.Count - 1)]
    }

    $resolvedCommand = $tokens[$commandIndex]
    $resolvedArgs = $args

    # If the "command" token isn't a known CLI command, treat it as a shorthand for:
    #   jax run -only <token>
    # This enables:
    #   ./jax/jax.ps1 <task>
    #   ./jax/jax.ps1 <task> -env ...
    # and keeps "plan" as a first-class command (it is handled by jax.ps1 as run -plan).
    $knownCommands = @(
        'help', 'init',
        # 'init-compat', 'init-legacy',
        'env', 'list-envs', 'list-tasks',
        'run', 'r', 'invoke', 'plan', 'autocomplete', 'create-flavour', 'settings', 'skill', 'info', 'vault'
    )

    $normalized = if ($null -eq $resolvedCommand) { '' } else { $resolvedCommand.ToLowerInvariant() }
    if ($knownCommands -notcontains $normalized) {
        $resolvedArgs = @($resolvedCommand) + @($resolvedArgs)
        $resolvedCommand = 'run'
    }

    # 'r' and 'invoke' are aliases for 'run' (same command, same semantics)
    if ($normalized -eq 'r' -or $normalized -eq 'invoke') {
        $resolvedCommand = 'run'
    }

    # Positional env/task shorthand:
    #   jax <env-path> [<task> ...]   ==   jax -env <env-path> -only <task>,<task>,...
    # An env path is recognized by containing '/' (client/flow form); task selectors never do.
    # Explicit -env still wins (static param overrides args downstream in run/plan).
    if ($resolvedCommand -in @('run', 'plan') -and $resolvedArgs.Count -ge 1) {
        $first = [string]$resolvedArgs[0]
        if (-not $first.StartsWith('-') -and $first.Contains('/')) {
            $positionalEnv = $first
            $positionalTasks = @()
            $passthrough = @()
            $i = 1
            while ($i -lt $resolvedArgs.Count) {
                $a = [string]$resolvedArgs[$i]
                if ($a.StartsWith('-')) {
                    $passthrough += $a
                    if (($i + 1) -lt $resolvedArgs.Count) {
                        $next = [string]$resolvedArgs[$i + 1]
                        if (-not $next.StartsWith('-')) {
                            $passthrough += $next
                            $i += 2
                            continue
                        }
                    }
                    $i++
                    continue
                }
                $positionalTasks += $a
                $i++
            }
            $rewritten = @('-env', $positionalEnv)
            if ($positionalTasks.Count -gt 0) {
                $rewritten += @('-only', ($positionalTasks -join ','))
            }
            $rewritten += $passthrough
            $resolvedArgs = $rewritten
        }
    }

    return @{
        Command = $resolvedCommand
        Args    = $resolvedArgs
    }
}
