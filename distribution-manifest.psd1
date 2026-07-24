@{
    Version = '0.1.9'
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
