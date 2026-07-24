# Jax zsh integration. All Jax logic remains in PowerShell.
typeset -g _jax_shell_root="${${(%):-%x}:A:h}"
typeset -g _jax_pwsh="$(command -v pwsh 2>/dev/null)"

_jax_invoke() {
    if [[ -z "$_jax_pwsh" || ! -x "$_jax_pwsh" ]]; then
        print -u2 "jax: PowerShell 7+ (pwsh) is required."
        return 127
    fi
    local entry_point="$1"
    shift
    JAX_SHELL_ENTRYPOINT="$entry_point" \
        "$_jax_pwsh" -NoLogo -NoProfile \
        -File "$_jax_shell_root/Jax.ShellLauncher.ps1" "$@"
}

jax() { _jax_invoke jax "$@" }
jx() { _jax_invoke jx "$@" }
jxs() { _jax_invoke jxs "$@" }

_jax_zsh_completion() {
    local -a candidates display_labels
    local candidate display_label
    while IFS=$'\t' read -r candidate display_label; do
        [[ -z "$candidate" ]] && continue
        candidates+=("$candidate")
        display_labels+=("${display_label:-$candidate}")
    done < <(
        "$_jax_pwsh" -NoLogo -NoProfile \
            -File "$_jax_shell_root/Jax.ShellCompletion.ps1" "$BUFFER" "$CURSOR" zsh 2>/dev/null
    )
    if (( ${#candidates[@]} > 0 )); then
        compadd -Q -d display_labels -a candidates
        # Start menu completion immediately. The standard select style
        # registered below upgrades it to zsh/complist's arrow-key UI.
        compstate[insert]=menu
    fi
}

_jax_enable_zsh_menu_completion() {
    zmodload -i zsh/complist 2>/dev/null || return 0
    # zsh escapes some non-ASCII characters in completion lists unless this
    # option is enabled. Keep Jax's emoji labels intact in UTF-8 terminals.
    local locale_name="${LC_ALL:-${LC_CTYPE:-$LANG}}"
    case "${locale_name:l}" in
        *utf-8*|*utf8*) setopt PRINT_EIGHT_BIT ;;
    esac
    # Direct compadd-based completers are evaluated before a command/tag menu
    # style can initialize MENUSELECT. Supply the standard global fallback
    # only when the user has not already chosen a completion-menu behavior.
    local existing_menu_style=''
    if ! zstyle -s ':completion:*' menu existing_menu_style; then
        zstyle ':completion:*' menu select=1
    fi
}

_jax_register_zsh_completion() {
    (( $+functions[compdef] )) || return 0
    compdef _jax_zsh_completion jax jx jxs
    if (( $+functions[add-zsh-hook] )); then
        add-zsh-hook -d precmd _jax_register_zsh_completion 2>/dev/null
    fi
}

_jax_enable_zsh_menu_completion

if (( $+functions[compdef] )); then
    _jax_register_zsh_completion
else
    # Some frameworks run compinit after user profile fragments. Register on
    # the first prompt as well so their later compinit cannot leave Jax on the
    # filesystem fallback completer.
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _jax_register_zsh_completion
fi
