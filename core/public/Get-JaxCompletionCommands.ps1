function Get-JaxCompletionCommands {
    [CmdletBinding()]
    param ()

    $commands = @(
        'help',
        'init',
        # 'init-compat',
        # 'init-legacy',
        'env',
        'list-envs',
        'run',
        'r',
        'invoke',
        'plan',
        'autocomplete',
        'create-flavour',
        'settings',
        'skill',
        'info'
    )

    $entries = Get-JaxHelpEntries
    foreach ($entry in $entries) {
        if (-not [string]::IsNullOrWhiteSpace($entry.Name)) {
            $commands += $entry.Name
        }
    }

    return @($commands | Sort-Object -Unique)
}
