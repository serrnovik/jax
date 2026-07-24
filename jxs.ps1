# Run a saved jax shortcut: same as: jax / jx -sc <name> [extra args...]
# Tab completion: jax/jax.auto-completion.ps1 rewrites "jxs ..." to "jx -sc ..." for the completer.
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $CommandArgs
)
$jaxPath = Join-Path $PSScriptRoot 'jax.ps1'
& $jaxPath -sc @CommandArgs
