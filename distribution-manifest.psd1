@{
    Version = '0.1.21'
    Files = @(
        'VERSION'
        'LICENSE'
        'README.md'
        'SECURITY.md'
        'Jax.psd1'
        'Jax.psm1'
        'Jax.Autocomplete.psm1'
        'jax.auto-completion.ps1'
        'jax.ps1'
        'jxs.ps1'
        'Install-JaxSkill.ps1'
        # Shipped so a downloaded package can install itself: `jax update` runs
        # this file out of the temp download rather than reimplementing staging,
        # backup, manifest validation, and shell integration a second time. The
        # manifest ships with it because that is the file the installer copies
        # from - a package carrying the installer but not the list it works off
        # fails on its first line.
        'Install-Jax.ps1'
        'distribution-manifest.psd1'
        'Uninstall-Jax.ps1'
    )
    Directories = @(
        'core'
        'shell'
        'skills'
        'templates'
    )
    DirectorySets = @(
        @{
            Target = 'MustachePlaceholders'
            Entries = @(
                'MustachePlaceholders.psm1'
                'functions'
                'private'
                'public'
            )
        }
        @{
            Target = 'plugins'
            Entries = @(
                'bob'
                'cleaning'
                'coverage'
                'docker'
                'dotenv'
                'dotnet'
                'helm'
                'machine'
                'node'
                'packaging'
                'publish'
                'teamcity'
                'terminal'
                'vault'
            )
        }
        @{
            Target = 'psake'
            Entries = @(
                'src'
                'LICENSE'
            )
        }
    )
}
