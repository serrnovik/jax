---
name: jax
description: Configure and operate repositories with the Jax PowerShell task runner. Use when installing or updating Jax, initializing a consumer repository, adding Jax agent guidance, discovering Jax environments or tasks, running a Jax task, or troubleshooting an unavailable Jax command.
---

# Jax

Use the installed `jx` command to manage repository-owned environments and
tasks. Keep Jax's runtime separate from the consumer repository.

## Command form

`jx` is the short alias of `jax`; both run the same CLI. Write `jx` with short
flags in every command you emit or run:

```sh
jx -e <client>/<env> -q run -o <Task>
```

| Long form          | Short | Meaning                                  |
| ------------------ | ----- | ---------------------------------------- |
| `-env`             | `-e`  | Target environment (usually required)    |
| `-only`            | `-o`  | Single task, script, or scenario         |
| `-scenario`        | `-s`  | Named scenario                           |
| `-from` / `-to`    | `-f` / `-t` | Task chain range                   |
| `-Quiet`           | `-q`  | Minimal output; errors still print fully |
| `-noSavedSettings` | `-nss`| Do not persist this run's settings       |
| `-RepoRoot`        | `-C`  | Target repository when outside it        |
| `-noBuild`         | `-nb` | Skip the build chain                     |
| `-noCache`         | `-nc` | Force re-reading discovered entities     |
| `-shortcut`        | `-sc` | Run a saved shortcut                     |

Two audiences, two forms:

- **Commands you run yourself**: add `-q` and `-nss`, so an automated run stays
  quiet and never writes `.jax/state.yml`.
  ```sh
  jx -e sample/dev -q run -o Build -nss
  ```
- **Commands you print for a person to run**: keep them short. Add `-q`, but
  leave `-nss` off — persisting settings is the human's choice.
  ```sh
  jx -e sample/dev -q run -o Build
  ```

Omit `-q` only when the user asks for verbose Jax output (`-nq`, `-Verbose`,
`-Debug`), or when you are debugging Jax itself.

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
   unpinned remote installation script. Jax prints a one-time hint after a run
   when a newer version is published; it reads a local cache only, refreshes in
   a detached background process, and is silent when offline. It never appears
   in agent or CI output because it is skipped whenever stdout is redirected.
   `JAX_NO_UPDATE_NOTICE=1` turns it off entirely.
5. `Install-JaxShellIntegration -Shell powershell` makes completion available
   before the first command in clean PowerShell sessions. zsh/bash users can
   run `Install-JaxShellIntegration` without `-Shell`; it installs `jax`, `jx`,
   and `jxs` as executables under `~/.jax/shell/bin`, puts that directory on
   `PATH`, and registers dynamic completion for the detected login shell.

## Initialize a consumer repository

Use an explicit repository path when working outside the target repository:

```sh
git -C <repo-path> status
jx -C <repo-path> init -client <client> -env <environment>
jx -C <repo-path> list-envs -q
jx -C <repo-path> list-tasks -e <client>/<environment> -q
jx -C <repo-path> search <pattern> -q          # which environment has a task; * and ? wildcards
jx -C <repo-path> -e <client>/<environment> -q run -o Build -nss
```

Review and commit the generated `.jax/jax.config.yml`, `env/`, and this skill.
Preserve `.jax/state.yml`, `.jax/logs/`, local override files, `.env`, and
Vault tokens as local-only data.

## Install or refresh this skill

Install the bundled guidance into the consumer repository with:

```sh
jx -C <repo-path> skill
```

This writes `.agents/skills/jax/`. Re-run it after upgrading Jax, then review
and commit the updated skill with the consumer repository.

## Run tasks from a non-interactive or agent shell

Since 0.1.11, zsh and bash integration installs `jax`, `jx`, and `jxs` as
executable shims in `~/.jax/shell/bin` and prepends that directory to `PATH`.
`PATH` is inherited by non-interactive shells, scripts, CI steps, and the shells
coding agents spawn, so `jx` is the same command everywhere — no `pwsh -Command`
wrapper, no sourced profile:

```sh
jx -C <repo-path> -e <client>/<environment> -q run -o <Task> -nss
```

Earlier releases defined `jax`/`jx`/`jxs` as shell *functions* delegating to a
private `_jax_invoke` helper. Agents that snapshot a shell by serialising its
functions captured the public wrappers without the helper, leaving the command
defined but unusable:

```text
jx:1: command not found: _jax_invoke
```

If you still see that, the shell predates 0.1.11 or the integration was never
re-run. Fix it once with `Install-JaxShellIntegration` (or reinstall Jax) and
open a new shell. Diagnose with `type jx`: an executable path means the shim is
active, a function body means the old wrapper is still loaded. Until it is
fixed, fall back to the module directly — Jax auto-loads from `PSModulePath`:

```sh
pwsh -NoLogo -NoProfile -Command 'jx -C <repo-path> -e <client>/<environment> -q run -o <Task> -nss'
```

## Run tasks safely

Use `-C` or `-RepoRoot` to make the target repository unambiguous. Follow the
two forms from **Command form**: `-q -nss` on commands you run, `-q` only on
commands you hand to a person.

Discover before running when repository conventions are unknown:

```sh
jx -C <repo-path> list-envs -q
jx -C <repo-path> list-tasks -e <client>/<environment> -q
jx -C <repo-path> search <pattern> -q          # which environment has a task; * and ? wildcards
jx -C <repo-path> -e <client>/<environment> -q run -o <Task> -nss
```

Environment configuration layers conventionally flow from `env/common/` to
`env/<client>/common/` to `env/<client>/<environment>/`. Repository settings
live in `.jax/jax.config.yml`; environment run configuration lives in
`jaxfile.yml`; local state and logs live under `.jax/` and must remain
uncommitted.

Vault and Docker plugins may be loaded without being active. Vault secret
resolution requires `plugins.config.vault.enabled: true` or an explicit
runtime override. Use `jx -C <repo-path> vault login` for interactive
authentication and `jx -C <repo-path> vault status` for diagnostics. Set
`plugins.config.vault.authMount` when GitHub auth is mounted somewhere other
than `auth/github`. Never place tokens, personal paths, or
environment-specific secrets in Jax config or agent instructions.
