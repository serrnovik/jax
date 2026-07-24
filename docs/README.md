# Jax

Jax is a PowerShell-first runner and config system for repo tasks. It discovers
environment flow files, expands variables, maps scenario items into run
entities, and dispatches them through pluggable runners (psake, pwshscript, and
container). The CLI is intentionally small; most orchestration is exposed as a
PowerShell API so it can be embedded in larger build flows.

This document reflects the current implementation plus the agreed structure and
plugin concepts (marked when not yet implemented).

## Requirements

- PowerShell 7+ (pwsh)
- Git (required for bob integration; set JAX_REPO_ROOT to override repo root)
- Optional: Docker (required for container runner)
- Bundled psake 4.9.1 runtime
- PowerShell YAML cmdlets, or the optional `powershell-yaml` fallback

If auto-install fails (offline or restricted environments), install manually:

```
Install-Module -Name powershell-yaml -Scope CurrentUser
```

When bob integration runs without git available, it stops with platform-specific
install guidance. If git is installed but no repo is initialized, it prompts to
initialize a repo or set `JAX_REPO_ROOT`.

## Quick Start

Initialize a minimal repo structure:

```
jax init -Client sample -Env dev -FlowConfig build -IncludeJaxfile
```

The generated config keeps the current repository contract visible without
writing compatibility-only conventions or unused layer samples.
Legacy flag `-BossConfig` remains accepted for compatibility.

Create additional environments interactively:

```
jax env init
```

For legacy repos that already use `code/bob-*.yml`, generate a compat config:

```
jax init-compat
```

Run a scenario explicitly:

```
jax run -env sample/dev -scenario default
```

List discovered environments:

```
jax list-envs
```

Use the API directly from the root of a standalone Jax source checkout:

```
Import-Module ./core/Jax.Core.psm1 -Force

$config = Get-JaxConfig -RepoRoot (Resolve-Path .).Path
$envs = Get-JaxEnvironments -RepoRoot (Resolve-Path .).Path -Config $config
$flow = Get-JaxFlowConfig -Paths $envs[0].FlowConfigs[0].ConfigPaths
$entities = Get-JaxScenarioRunEntities -FlowConfig $flow -Scenario 'default'
Invoke-JaxRunEntities -Entities $entities
```

## Concepts

- Repo root
  Jax resolves the repo root in this order:
  1. JAX_REPO_ROOT environment variable
  2. git rev-parse --show-toplevel
  3. Walk up for .git (file or directory, supports submodules)

- Environment root
  Default: env/. Each env directory can contain flow directories and scripts.

- Flow directories
  Default name: flows/. Each flow file is YAML and defines suite.scenarios.
  Repositories that still use boss/ can add it to `flowDirNames`.

## Flow Examples (build / publish / k8s)

Each flow is a YAML file under `flows/`. The filename becomes the flow
`Configuration` (for example, `build.yml` -> `build`). A flow defines one or
more scenarios under `suite.scenarios`, and each scenario item turns into a run
entity. Strings map to psake tasks by default, while dictionaries can specify
runner/task/script/args/container details.

Common flow steps can live in `env/common/flows/` and be overridden by
`env/<client>/common/flows/` and `env/<client>/<env>/flows/` (lower levels win).

Example: build flow shared at repo level, overridden for a specific env:

```
# env/common/flows/build.yml
suite:
  scenarios:
    default:
      - Restore
      - Build
      - Test

# env/acme/dev/flows/build.yml
suite:
  scenarios:
    default:
      - Restore
      - Build
      - TestFast
    full:
      - Restore
      - Build
      - Test
```

Example: publish flow (zip + report script):

```
# env/acme/dev/flows/publish.yml
suite:
  scenarios:
    default:
      - PublishZip
      - PublishNuget
      report:
        script: scripts/publish-report.ps1
        args:
          destination: "out/publish"
```

Example: k8s flow (build + deploy, optionally in a container):

```
# env/acme/dev/flows/k8s.yml
suite:
  scenarios:
    default:
      - BuildImage
      - PushImage
      deploy:
        runner: psake
        tasks:
          - DeployK8s
        container:
          image: "ghcr.io/acme/k8s-tools:latest"
```

Loading a specific flow (merged across the hierarchy) and expanding a scenario:

```
$config = Get-JaxConfig
$envs = Get-JaxEnvironments -Config $config
$flow = $envs | Where-Object { $_.Name -eq 'acme/dev' } |
    Select-Object -ExpandProperty FlowConfigs |
    Where-Object { $_.Configuration -eq 'build' }
$flowConfig = Get-JaxFlowConfig -Paths $flow.ConfigPaths
$entities = Get-JaxScenarioRunEntities -FlowConfig $flowConfig -Scenario 'default'
```

- Scenario
  A map of run items, expanded into run entities. The order is preserved.

- Run entity
  A normalized object with Runner (psake/pwshscript/container), Tasks, Script,
  Args, and optional Container settings.

- Runner
  A pluggable execution adapter. Built-ins: psake, pwshscript, container,
  scenario. Aliases: script -> pwshscript. Reserved names for future runners:
  bashscript, cmdscript.

## Advanced Scenario Runners

### Scenario Runner with Mixed Steps

Use the `scenario` runner (or its alias `sceny`) to compose workflows from multiple steps with different runners:

```yaml
# env/client/env/scenarios-lib/workflows.yml
test_batch:
  runner: sceny # alias for 'scenario'
  args:
    myData: 'root-value' # passed to all steps
  steps:
    - step1
    - step2
    - step3

step1:
  runner: psake
  script: 'psakefile.ps1'
  tasks:
    - Test1
  args:
    stepName: 'step1'
    # myData: inherited from test_batch

step2:
  runner: pwsh
  script: 'scripts/test-script.ps1'
  args:
    stepName: 'step2'
    # myData: inherited from test_batch

step3:
  runner: psake
  script: 'psakefile.ps1'
  tasks:
    - Test2
  args:
    stepName: 'step3'
    myData: 'overridden-value' # overrides root value
```

Run with:

```bash
jax run -env client/env -only test_batch
```

### Runner Name Aliases

**Scenario runner aliases:**

- `scenario` - Full name
- `sceny` - Short alias
- `bossscenario`, `boss-scenario` - Legacy aliases

**Script runner aliases:**

- `pwshscript` - Full name
- `pwsh`, `powershell`, `ps1`, `script` - All resolve to `pwshscript`
- `bash`, `sh` - Resolve to `bashscript`
- `cmd`, `bat`, `batch` - Resolve to `cmdscript`

### NoCache Flag

Force re-reading of all discovered entities (tasks, scripts, library items):

```bash
jax run -env client/env -only test_batch -noCache

# or with alias:
jax run -env client/env -only test_batch -nc
```

This bypasses entity caching and ensures the latest configuration is loaded.

### Edge Cases

**Psake with `script` instead of `psakeFile`:**
The dictionary resolver automatically normalizes `script:` to `PsakeFile:` when the runner is `psake`:

```yaml
my_task:
  runner: psake
  script: 'psakefile.ps1' # auto-copied to PsakeFile
  tasks:
    - Build
```

## Repository Layout (Current + Agreed Structure)

Concise structure created by `jax init`:

```
.jax/
  jax.config.yml
env/
  common/
  <client>/
    common/
    <env>/
```

The full hierarchy (env/common, env/<client>/common,
env/<client>/<env>) includes flows, scripts, psakefiles, scenarios-lib, and
tracked anchors for otherwise empty directories.

Environment hierarchy (flows merged by default):

```
env/
  common/
    flows/          # repo-wide flows
    scripts/
    scenarios-lib/
  <client>/
    common/
      flows/
      scripts/
      scenarios-lib/
    <env>/
      flows/
      scripts/
      scenarios-lib/
```

Resolution order (lowest overrides highest):

1. env/common
2. env/<client>/common
3. env/<client>/<env>

This mirrors the legacy behavior and enables deeper hierarchies later. Flow
config entries expose `ConfigPaths` (ordered low -> high) so you can load a
fully merged flow file in one call.
Scenarios-lib inheritance follows the same hierarchy and is implemented.
Script inheritance is staged for later implementation.

## Configuration

Repo configuration:
.jax/jax.config.yml

User configuration:

- ~/.jax/config.yml

Merge order (highest wins):

1. Overrides (passed to Get-JaxConfig)
2. User config
3. Repo config
4. Defaults

Schema (defaults):

```
jax:
  envRoot: env
  dummyEnv:
    enabled: true
    name: none
    skipEnvRoot: true
  flowDirNames:
    - flows
  flowFilePatterns:
    - "*.yml"
    - "*.yaml"
  buildSectionNames:
    - build
    - modules
  conventionalEnvRoots:
    - code
  commonDirName: common
  scenarioLibDirName: scenarios-lib
  tasks:
    psakeFilePattern: "psakefile*.ps1"
    nonConventionalDirs: []
  scripts:
    dirNames:
      - scripts
    nonConventionalDirs: []
  modulePathInGit: {}
  taskIgnoreList: []
  aliases: {}
  plugins:
    enabled:
      - machine
      - bob
    disabled:
      - cleaning
      - vault
      - dotenv
      - hi
      - nav
      - terminal
      - autocomplete
      - dotnet
      - node
      - docker
      - packaging
      - tests
      - helm
      - publish
    paths: []
    config:
      bob:
        fileBaseNames:
          - "jaxfile"
        fileExtensions:
          - "yml"
          - "yaml"
        defaults: {}
        expandVariables: true
        ignoreMissingPlaceholders: false
        git:
          require: true
          allowInit: true
          prompt: true
        layers:
          repoCommonPatterns:
            - "configs/jax/common/*.yml"
            - "configs/jax/common/*.yaml"
          localOverridePatterns:
            - "configs/jax/local-override*.yml"
            - "configs/jax/local-override*.yaml"
          ciOverridePatterns:
            - "configs/jax/ci-*.yml"
            - "configs/jax/ci-*.yaml"
          flavourDir: "configs/jax-flavours"
          flavourPatterns:
            - "*.yml"
            - "*.yaml"
          ciEnvVars:
            - "CI"
          overrides: {}
      cleaning:
        enabled: false
      machine: {}
      vault:
        enabled: false
        # Optional child-token policy and TTL are configured by `jax vault set`.
      dotenv:
        enabled: false
        files:
          - ".env"
      dotnet: {}
      node: {}
      docker: {}
      packaging: {}
      tests: {}
      helm: {}
      publish: {}
  cache:
    enabled: true
    dir: ".jax/cache"
```

Computed build environments:

- Each `conventionalEnvRoots` entry is scanned for `psakefile*.ps1`. Any
  directory containing a psakefile becomes a computed env, so the roots define
  where convention-discovered envs live (typical roots: `code`, `devops`).
  Legacy aliases `buildEnvRoots` (plural) and `buildEnvRoot` (singular) are
  still accepted and normalized to `conventionalEnvRoots` on load.
- A module at `code/operations/backups` accepts legacy
  `build/operations/backups`, rooted `code/operations/backups`, and short
  `operations/backups` when the short path is unique.
- If multiple build roots contain the same relative path, autocomplete shows the
  rooted names and the short alias is not accepted.
- Computed build env autocomplete icons use the displayed path: the first path
  segment resolves through `autocomplete.clientIcons`, and the leaf segment may
  add a second icon from `autocomplete.flowIcons` when configured.

Dummy environment:

- Use `dummyEnv` to run repo-wide tasks without an `env/` tree.
- Default is `none`, so `jax -env none run <Task>` bypasses env-root discovery.
- The dummy env appears in autocomplete; customize its icon via
  `jax.autocomplete.clientIcons.none`.
- Set `dummyEnv.enabled: false` to disable the shortcut.

Validation:

- Config files are validated on load.
- Wrong types trigger a clear error with the key path and a best-effort line
  reference.

## Run Config (jaxfile; legacy bobfile)

Run config files provide per-environment settings, defaults, and module options
for tasks. New repositories use `jaxfile.yml`/`jaxfile.yaml`. Repositories that
still use `bobfile.yml`/`bobfile.yaml` can opt into that base name in
`plugins.config.bob.fileBaseNames`.

Location:

- `env/<client>/<env>/jaxfile.yml` (preferred)
- `env/<client>/<env>/bobfile.yml` (legacy)

Selection and merge behavior:

- Env hierarchy is merged in order:
  `env/common` -> `env/<client>/common` -> `env/<client>/<env>`, with lower
  levels overriding higher ones.
- Jax checks file names in the order configured by
  `plugins.config.bob.fileBaseNames`. The default list contains only `jaxfile`.
- `import` entries are resolved relative to the run-config file directory or
  with `^/` to anchor at the repo root.
- Imports are merged in order; earlier imports win over later imports.
- The local run-config always overrides imported values.

Layered merge order (highest wins):

1. CLI overrides (passed as `Context.RunConfigOverrides`)
2. User run-config (passed as `Context.RunConfigUser`)
3. Repo run-config (includes common/local/ci/named/flavour layers)
4. Env run-config (passed as `Context.RunConfigEnv`)
5. configured run-config file (`jaxfile` by default)
6. Plugin defaults (`plugins.config.bob.defaults`)

The bob plugin attaches the final merged run config to `Context.RunConfig`
during `BeforeSequenceResolve`.

CLI flags that populate these layers are still mostly supplied via the context
object when calling the API, but named overrides can be selected from the CLI
using `-override` or `-overrides` (comma-separated).

To bypass git checks in non-git contexts, set
`plugins.config.bob.git.require: false` (not recommended for normal use).

## Config Layers (Repo, Local, CI, Flavour)

Jax can merge additional run-config layers from conventional locations. These
layers sit above the env-specific run-config and are merged in this order:

1. `configs/jax/common/*.yml`
2. `configs/jax/local-override*.yml`
3. `configs/jax/ci-*.yml` (only when CI is detected)
4. `configs/jax-flavours/<name>.yml` (when `Context.Flavour` is set)

CI detection defaults to the generic `CI` environment variable, or you can
force it with `Context.Ci = $true`.

All of these paths and patterns are configurable under
`plugins.config.bob.layers`.

Named overrides let you select specific override files by name:

```
jax:
  plugins:
    config:
      bob:
        layers:
          overrides:
            teamcity:
              - "configs/jax/ci-teamcity-override.yml"
            quick:
              - "configs/jax/ci-quick.yml"
```

Use `Context.Override = 'teamcity'` (or `Context.Overrides = @('teamcity', 'quick')`)
to activate them. The CLI maps `-override teamcity` (or `-overrides teamcity,quick`)
into the same context values.

Example flavour file:

```
# configs/jax-flavours/mint.yml
name: "mint"
description: "Local dev flavour with faster builds"
# override example:
# module:
#   dotnet:
#     sdk: "8.0.100"
```

Example CI override file (imports allowed):

```
# configs/jax/ci-dev.yml
import:
  - "^/code/jax-node-common.yml"
module:
  ci: true
```

Example CI override file with multiple imports:

```
# configs/jax/ci-teamcity-override.yml
import:
  - "^/code/jax-install-common.yml"
  - "^/code/jax-node-common.yml"
module:
  ci: true
  docker:
    enabled: true
```

## Plugins and Hooks

Plugins are modules that register hook handlers. Hooks are invoked with a
context object that includes the active config, plugin config, and optional
data payloads. Hook names currently used by core:

- BeforeSequenceResolve / AfterSequenceResolve
- BeforeRunEntities / AfterRunEntities
- BeforeRunEntity / AfterRunEntity

Current implementation includes the plugin loader and basic built-in plugins:
machine and bob (enabled by default), plus cleaning/vault/dotenv (disabled by
default).

Enable/disable plugins via config:

```
jax:
  plugins:
    enabled: [machine, cleaning]
    disabled: [vault, dotenv]
    paths:
      - ^/jax/plugins/custom/Custom.Plugin.psm1
    config:
      cleaning:
        enabled: true
```

### Docker plugin (build push/arch controls)

The `docker` plugin provides compatibility flags that control Docker build behavior by
injecting overrides into psake properties at runtime:

- `module.docker.push`
- `module.docker.onlyLocalArch`

This directly affects docker build tasks that call `Get-DockerBuildConfigBase`
(for example `code/docker/psakefile-staticdocker-tasks.ps1`).

**Flags (available when the plugin is enabled):**

- `-pushToDockerRegistry` (aliases: `-push`, `-pushDocker`, `-pushHarbor`, `-pushToDocker`)
  - Forces `module.docker.push = true` for this run.
- `-onlyLocalArch`
  - Forces `module.docker.onlyLocalArch = true` for this run (single-arch build).
- `-pushLocal`
  - Forces `module.docker.push = true` and switches to the local registry if configured via
    `plugins.config.docker.localRegistry`.

**Defaults:**

If you don’t pass CLI overrides, the plugin uses `plugins.config.docker.defaults`:

- `defaults.local` when not in CI
- `defaults.ci` when CI is detected (`TEAMCITY_VERSION`, `TEAMCITY_BUILD_PROPERTIES_FILE`, or `CI`)

**Persistence:**

If you pass any of the docker CLI overrides above, the plugin persists your choice under
`.jax/state.yml` (unless `-noSavedSettings` is used).

## Persistent Settings (state.yml)

Jax persists lightweight state in `.jax/state.yml` (opt-out via
`-NoSavedSettings` on state functions). Core defaults include `env`, `client`,
`scenario`, `from`, `to`, and `docker` flags. Plugins can register their own
defaults via `Register-JaxPersistentSetting`.

## Flow Files and Scenarios

Example flow file (env/<client>/<env>/flows/build.yml):

```
suite:
  scenarios:
    default:
      build: Build
      lint: Lint
      deploy:
        runner: pwshscript
        script: scripts/deploy.ps1
```

Scenario items can be:

- String: task name or script path (if ends with .ps1/.sh/.cmd)
- Array: list of tasks
- Dictionary: explicit runner + fields

## Container Runner

Container execution is supported for any run entity when:

- The entity defines container.image, or
- You force container execution via -Docker/-Container and a default image is
  present in run-config (`container.image`, `module.docker.image`, or `docker.image`).

The repo root is mounted at /jax/src inside the container. Paths under the repo
are rewritten to /jax/src/... for container execution.

## CLI Commands

- jax help
  Prints available commands.

- jax init
  Creates .jax/jax.config.yml (if missing), env/<client>/<env>/flows/<name>.yml,
  and env/<client>/<env>/scripts/. Optionally creates jaxfile.yml/bobfile.yml.
  Use -FlowConfig to choose the flow file name (legacy -BossConfig also works).

- jax init-compat (alias: init-legacy)
  Writes a compatibility config that mirrors legacy layout conventions
  (boss-first flow discovery and code/bob-\*.yml run-config layers).

- jax env init
  Interactive scaffolding for env/common, env/<client>/common, and
  env/<client>/<env>. Prompts for default flow name and optional additional
  flows, creates flow files, scripts, psakefiles, and scenarios-lib.

- jax list-envs
  Lists environments discovered under env/ and shows flow configs.

- jax create-flavour
  Creates a flavour file under configs/jax-flavours with a minimal template.

- jax run (alias: r)
  Executes a flow scenario (explicit). Supports selection flags such as
  -env (-e), -scenario (-s), -from (-f)/-to (-t)/-only (-o), -noBuild (-nb),
  and -buildChainOnly (-bo), plus -override/-overrides for named run-config
  overrides and -docker/-container to force container execution. Use
  -forceReloadModules to reload repo-local PowerShell modules before execution.

  **Implicit run**: The `run` command can be omitted when run-like flags are
  present. A bare task name is treated as `-only <task>`. Examples:
  ```
  jax run -e myenv -o MyTask      # explicit
  jax r -e myenv MyTask           # 'r' alias, positional -only
  jax -e myenv MyTask             # implicit run, positional -only
  ```

  **Ad-hoc scenarios**: `-only/-o` also accepts multiple task/entity selectors
  as a PowerShell array or comma-separated value. Jax resolves each selector in
  the order provided, wraps them in a virtual scenario for that invocation, and
  then executes that scenario. `-from/-to` slice inside the selected scenario
  (including this virtual scenario) rather than the global plan.

  ```
  jax run -e myenv -o BuildAsr,BuildPhoneme,BuildEngine
  jax run -e myenv -o 'BuildAsr,BuildPhoneme,BuildEngine' -from BuildPhoneme
  ```

  **State persistence**: `-env`, `-client`, `-scenario` persist to
  `.jax/state.yml` across runs. `-from`, `-to`, `-only` are ephemeral.

- jax plan
  Prints the run plan without executing. Equivalent to `jax run -plan`
  (legacy `-dryRunShort` still works).

- jax autocomplete
  Registers tab completion for the current PowerShell session. Autocomplete
  supports implicit run (task suggestions when `-e` is present without `run`),
  the `r` alias, and shows the resolved environment in tooltips (including
  whether it was inferred from saved state).

- jax settings reset
  Removes `.jax/state.yml` for the current repo.

## Logs

Jax writes detailed logs under `.jax/logs`:

- `plan_*.log`: resolved run entities for the current execution.
- `run-config_*.json`: merged run-config after imports and variable expansion.
- `psake-params_*.json`: psake build file, task list, and properties.

## Core API

Import:

```
Import-Module jax/core/Jax.Core.psm1 -Force
```

Key functions:

- Get-JaxConfig
  Loads and merges defaults, repo config, user config, and overrides.

- Get-JaxEnvironments
  Discovers environments and flow configs based on flowDirNames and patterns.
  Includes HierarchyPaths/HierarchyFlowDirs plus FlowConfig.ConfigPaths for
  env/common layering.

- Get-JaxEnvHierarchyPaths
  Returns env/common -> env/<client>/common -> env/<client>/<env> for a given env.

- Get-JaxFlowConfig
  Reads flow YAML and expands variables by default. Use -Paths for layered
  configs, or -ExpandVariables:$false to skip.

- Get-JaxScenarioRunEntities
  Expands suite.scenarios into run entities (ordered).

- Resolve-JaxScenarioItemToRunEntity
  Resolves a single scenario item using the registered resolvers.

- Expand-JaxPlaceholders
  Expands {{ }} substitutions using the internal MustachePlaceholders module.

- Get-JaxRepoRoot
  Resolves the repo root using git, .git markers, or JAX_REPO_ROOT.

- Merge-JaxHashtable
  Deep merge helper used by config and run-config layering.

- Invoke-JaxRunEntity
  Dispatches a single run entity to the runner registry. Use -Docker/-Container
  to force container execution and -ContainerImage for default image selection.

- Invoke-JaxRunEntities
  Runs a sequence of entities with a shared context (supports -Override/-Overrides
  for named override layers).

- Invoke-JaxEnvInit
  Interactive env scaffolding (env/common, env/<client>/common, env/<client>/<env>).

- Invoke-JaxInitCompatConfig
  Writes a compatibility config that mirrors a legacy repository layout.

- Register-JaxRunner
  Registers or replaces a runner handler.

- Register-JaxPlugin / Import-JaxPlugins / Get-JaxPlugins
  Plugin registry and loader for hook-based extensions.

- Invoke-JaxHooks
  Invokes registered plugin hooks (BeforeRunEntity, etc.).

- Register-JaxPersistentSetting / Get-JaxState / Update-JaxState / Reset-JaxState
  Lightweight persisted state in `.jax/state.yml`.

- Register-JaxScenarioResolver
  Registers a resolver to map custom scenario items into run entities.

- Read-JaxYaml / Write-JaxYaml
  YAML helpers backed by powershell-yaml.

- Write-JaxRunConfigLog
  Writes the merged run-config to `.jax/logs` as JSON.

## Plugins (Current + Planned)

Jax is moving toward a plugin-first architecture. The following plugins are
agreed; basic scaffolds are implemented for several of them.

- bob (implemented, core integration)
  - Purpose: merge jaxfile/bobfile layers + scenarios-lib items.
  - Inputs: run-config paths + merge order.
  - Outputs: merged run config + library items.
  - Hooks: BeforeSequenceResolve.
  - Tools: git (required).

- machine (implemented, minimal)
  - Purpose: basic host info (OS, git availability, shell).
  - Hooks: BeforeSequenceResolve.

- vault (implemented, minimal)
  - Purpose: HashiCorp Vault integration for secrets.
  - Hooks: BeforeSequenceResolve / BeforeRunEntity.
  - Config: plugins.config.vault.policy (required when running `jax vault set`).

- dotenv (implemented, minimal)
  - Purpose: local .env loader with configurable patterns.

- cleaning (implemented, disabled by default)
  - Purpose: opt-in cleaning steps.

- dotnet (scaffold)
- node (scaffold, npm/pnpm)
- docker (scaffold)
- packaging (scaffold)
- tests (scaffold)
- helm (scaffold)
- publish (scaffold)

- hi (planned, bonus)
  - Purpose: repo-local session bootstrap (`jax hi`) for aliases, completions,
    secrets, terminal UI, and navigation.

- nav (planned)
  - Purpose: path registry + navigation helpers and completion.

- terminal (planned)
  - Purpose: terminal adapters (Windows Terminal, iTerm2, generic) for tab
    color/title and related UX.

Autocomplete is implemented as a core CLI command (`jax autocomplete`) that
registers completion for the current PowerShell session.

Autocomplete icons:

- Dummy env completion uses the env name (default `none`) as the client key.
- Add `autocomplete.clientIcons.none` to distinguish it (example: `🚫`).

## Path Resolution Rules

Resolve-JaxRepoRootedPath supports:

- Absolute paths
- Repo-rooted paths using ^/prefix (example: ^/env/common/psakefile.ps1)
- Relative paths (resolved against RepoRoot or WorkingDir)

## Extending Jax

- Runners: use Register-JaxRunner to add a new runner.
- Scenario items: use Register-JaxScenarioResolver to map a new item type.

Example custom resolver:

```
Register-JaxScenarioResolver -Name 'bash' -Order -50 -Handler {
    param($Key, $Value, $ScenarioName, $ProvenancePath)
    if ($Value -isnot [hashtable] -or $Value.runner -ne 'bash') { return $null }
    $entity = New-Object System.Collections.Specialized.OrderedDictionary
    $entity['Key'] = $Key
    $entity['Runner'] = 'bashscript'
    $entity['Script'] = $Value.script
    $entity['Args'] = $Value.args
    return $entity
}
```

## Troubleshooting

- YAML errors: ensure powershell-yaml is installed and the config types match
  the schema.
- psake errors: ensure psake 4.9.1 is installed.
- Container runner errors: ensure Docker is available and the image is
  accessible.

## Status

Jax currently covers config loading, discovery, variable expansion, scenario
expansion, runner dispatch (psake/pwshscript/container), and a minimal CLI for
init and env listing.
