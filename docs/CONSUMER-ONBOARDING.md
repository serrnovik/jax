# Consumer repository onboarding

## One-time workstation setup

1. Install PowerShell 7.2+ and Git.
2. Run `Install-PSResource Jax -Scope CurrentUser -TrustRepository`.
3. Run `Import-Module Jax`.
4. Run `Install-JaxShellIntegration -Shell powershell` once so completion is
   ready in every new PowerShell session, then run `jax help`.

Use `Install-Module Jax -Scope CurrentUser -Repository PSGallery` when
PowerShellGet v2 is the available package manager.

For zsh or bash, run `Install-JaxShellIntegration` without `-Shell`; it
registers PowerShell plus the detected login shell. The generated shell
functions route arguments and completion through `pwsh`; they do not duplicate
the Jax runtime.

## Add Jax to a repository

From any directory:

```powershell
git -C <repo-path> status
jax -C <repo-path> init -client <client> -env <environment>
jax -C <repo-path> list-envs
jax -C <repo-path> list-tasks -env <client>/<environment>
jax -C <repo-path> run -env <client>/<environment> -only Build -noSavedSettings
jax -C <repo-path> skill
jax -C <repo-path> info
```

Review and commit the generated `.jax/jax.config.yml` and `env/` files. Do not commit `.jax/state.yml`, `.jax/logs/`, local override files, `.env`, or Vault tokens.

The generated repo config is intentionally concise but explicit. It records the
repository layout, discovery rules, icons, and enabled plugins so humans and
agents can understand the contract without knowing Jax internals. Add
repository-wide changes deliberately. Compatibility-only conventions such as
`boss`, `bobfile`, and TeamCity-specific layer names remain supported when
configured, but are not written into new repositories.

`jax skill` installs the bundled Jax guidance into `.agents/skills/jax/` in the
consumer repository. Review and commit it so future AI-assisted work uses the
same repository setup, discovery, and secret-handling rules.

`jax info` is safe to include in a support report: it displays installation,
Git, and configuration presence without reading out configuration values,
tokens, or secrets.

## Repository ownership boundary

| Installed Jax owns | Consumer repository owns |
| --- | --- |
| CLI launcher and module | `.jax/jax.config.yml` |
| Built-in plugins | environment directories |
| Placeholder functions | flows and scenarios |
| Generic templates | psakefiles and scripts |
| Bundled psake runtime | project-specific modules and secrets wiring |

Consumer configuration must not reference the Jax checkout. The installer location can change without editing consumer repositories.

## CI

For CI, pin the Gallery version:

```powershell
Install-PSResource Jax -Version <version> -Scope CurrentUser -TrustRepository
Import-Module Jax -RequiredVersion <version> -Force
jax -C "$PWD" run -env <environment> -only <task> -noSavedSettings -q
```

Do not run an unpinned remote installation script.

## Adoption checklist

- [ ] Global or job-local installation succeeds.
- [ ] `jax -C <repo> list-envs` discovers the expected environments.
- [ ] `list-tasks` discovers psake and script tasks.
- [ ] local state and secrets are ignored.
- [ ] CI pins a Jax revision.
- [ ] old vendored Jax runtime is removed only after the installed command passes smoke tests.
