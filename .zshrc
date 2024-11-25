# Plugins
source /usr/share/zinit/zinit.zsh 

zinit ice depth=1

zinit light Aloxaf/fzf-tab
zinit light jeffreytse/zsh-vi-mode
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-syntax-highlighting

# Snippets
zinit snippet OMZP::archlinux
zinit snippet OMZP::git
zinit snippet OMZP::sudo

# Load completions
autoload -Uz compinit && compinit
zinit cdreplay -q

# Aliases
source "$HOME/.config/aliasrc"

# History settings
HISTDUP=erase
HISTFILE=~/.zsh_history
HISTSIZE=5000
SAVEHIST=$HISTSIZE
setopt appendhistory
setopt hist_find_no_dups
setopt hist_ignore_all_dups
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_save_no_dups
setopt sharehistory
setopt glob_dots

# Completion styling
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu no
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:cd:*' popup-pad 50 0

# lf jumper (TODO: Remove once yazi is ripe)
lfcd () {
    tmp="$(mktemp)"
    # `command` is needed in case `lfcd` is aliased to `lf`
    command lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir="$(cat "$tmp")"
        rm -f "$tmp"
        if [ -d "$dir" ]; then
            if [ "$dir" != "$(pwd)" ]; then
                cd "$dir"
            fi
        fi
    fi
}

# Yazi jumper
function yy() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

zvm_after_init_commands+=(eval "$(fzf --zsh)")
zvm_after_init_commands+=(eval "$(navi widget zsh)")
zvm_after_init_commands+=(eval "$(zoxide init zsh)")

# Starship prompt
eval "$(starship init zsh)"

# Node Version Manager
eval "$(fnm env --use-on-cd --shell zsh)"

# Direnv
eval "$(direnv hook zsh)"

autoload -Uz add-zsh-hook

add-zsh-hook -Uz apply_keybindings() {
  bindkey '^@' autosuggest-accept
}

apply_keybindings
