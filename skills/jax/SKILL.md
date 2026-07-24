---
name: jax
description: Configure and operate repositories with the Jax PowerShell task runner. Use when installing or updating Jax, initializing a consumer repository, adding Jax agent guidance, discovering Jax environments or tasks, running a Jax task, or troubleshooting an unavailable Jax command.
---

# Jax

Use the installed `jax` command to manage repository-owned environments and
tasks. Keep Jax's runtime separate from the consumer repository.

## Verify or install Jax

1. Check availability with `Get-Command jax -ErrorAction SilentlyContinue`.
2. If Jax is unavailable, install the public package:

   ```powershell
   Install-PSResource Jax -Scope CurrentUser -TrustRepository
   Import-Module Jax
   Install-JaxShellIntegration -Shell powershell
   ```

3. Use `Install-Module Jax -Scope CurrentUser -Repository PSGallery` only when
   PowerShellGet v2 is required.
4. Update with `Update-PSResource Jax -Scope CurrentUser -Repository PSGallery
   -TrustRepository`. Do not clone Jax into a consumer repository or execute an
   unpinned remote installation script.
5. `Install-JaxShellIntegration -Shell powershell` makes completion available
   before the first command in clean PowerShell sessions. zsh/bash users can
   run `Install-JaxShellIntegration` without `-Shell`; it also installs the
   argument-safe wrapper and dynamic completion for the detected login shell.

## Initialize a consumer repository

Use an explicit repository path when working outside the target repository:

```powershell
git -C <repo-path> status
jax -C <repo-path> init -client <client> -env <environment>
jax -C <repo-path> list-envs
jax -C <repo-path> list-tasks -env <client>/<environment>
jax -C <repo-path> run -env <client>/<environment> -only Build -noSavedSettings
```

Review and commit the generated `.jax/jax.config.yml`, `env/`, and this skill.
Preserve `.jax/state.yml`, `.jax/logs/`, local override files, `.env`, and
Vault tokens as local-only data.

## Install or refresh this skill

Install the bundled guidance into the consumer repository with:

```powershell
jax -C <repo-path> skill
```

This writes `.agents/skills/jax/`. Re-run it after upgrading Jax, then review
and commit the updated skill with the consumer repository.

## Run tasks safely

Use `-C` or `-RepoRoot` to make the target repository unambiguous. Agents
should add `-q` / `-Quiet` to Jax invocations unless verbose output is needed,
and should use `-noSavedSettings` for reproducible automation. When presenting
commands for a human to copy, omit `-noSavedSettings` unless it is important to
the example.

Discover before running when repository conventions are unknown:

```powershell
jax -C <repo-path> list-envs -q
jax -C <repo-path> list-tasks -env <client>/<environment> -q
jax -C <repo-path> run -env <client>/<environment> -only <Task> -q -noSavedSettings
```

Environment configuration layers conventionally flow from `env/common/` to
`env/<client>/common/` to `env/<client>/<environment>/`. Repository settings
live in `.jax/jax.config.yml`; environment run configuration lives in
`jaxfile.yml`; local state and logs live under `.jax/` and must remain
uncommitted.

Vault and Docker plugins may be loaded without being active. Vault secret
resolution requires `plugins.config.vault.enabled: true` or an explicit
runtime override. Use `jax -C <repo-path> vault login` for interactive
authentication and `jax -C <repo-path> vault status` for diagnostics. Set
`plugins.config.vault.authMount` when GitHub auth is mounted somewhere other
than `auth/github`. Never place tokens, personal paths, or
environment-specific secrets in Jax config or agent instructions.
