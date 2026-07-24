Set-StrictMode -Version Latest

# Register argument completers in module scope so they persist after `./jax/jax.ps1 autocomplete` returns.
. (Join-Path $PSScriptRoot 'jax.auto-completion.ps1')
