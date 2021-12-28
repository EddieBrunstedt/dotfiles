# Eddie's zsh config

### Zinit Initialization
if [[ ! -f $HOME/.zinit/bin/zinit.zsh ]]; then
    print -P "%F{33}▓▒░ %F{220}Installing DHARMA Initiative Plugin Manager (zdharma/zinit)…%f"
    command mkdir -p "$HOME/.zinit" && command chmod g-rwX "$HOME/.zinit"
    command git clone https://github.com/zdharma/zinit "$HOME/.zinit/bin" && \
        print -P "%F{33}▓▒░ %F{34}Installation successful.%f" || \
        print -P "%F{160}▓▒░ The clone has failed.%f"
fi
source "$HOME/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit
### End of Zinit Initialization

## Plugins
zinit load zsh-users/zaw
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma/fast-syntax-highlighting
zinit load zdharma/history-search-multi-word #Multi-word, syntax highlighted history searching for Zsh

export KEYTIMEOUT=1

# vi mode
bindkey -v
bindkey -v '^?' backward-delete-char

# Enable colors
autoload -U colors && colors

# Use bat as man pager
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
# Limit the man width
export MANWIDTH=80

# History in cache directory:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# Suggestions
ZSH_AUTOSUGGEST_STRATEGY=(history completion) # Auto-suggestion strategy
ZSH_AUTOSUGGEST_USE_ASYNC=YesPls # Suggestions fetched asynchronously

# Enable searching through history
bindkey '^R' history-incremental-pattern-search-backward

# Accept autosuggestion
bindkey '^ ' autosuggest-accept

# Load aliases if existent
[ -f "$HOME/.config/aliasrc" ] && source "$HOME/.config/aliasrc"

autoload -Uz compinit && compinit
zstyle ':completion:*' menu yes select
zmodload zsh/complist
compinit

# Include hidden files in autocomplete
_comp_options+=(globdots)

# Use vim keys in tab complete menu
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history

# Change cursor shape for different vi modes
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] ||
     [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'

  elif [[ ${KEYMAP} == main ]] ||
       [[ ${KEYMAP} == viins ]] ||
       [[ ${KEYMAP} = '' ]] ||
       [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'
  fi
}
zle -N zle-keymap-select

zle-line-init() {
    zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
    echo -ne "\e[5 q"
}
zle -N zle-line-init

# Use beam shape cursor on startup.
echo -ne '\e[5 q'
# Use beam shape cursor for each new prompt.
preexec() { echo -ne '\e[5 q' ;}

# Use lf to switch directories and bind it to ctrl-o
lfcd () {
    tmp="$(mktemp)"
    lf -last-dir-path="$tmp" "$@"
    if [ -f "$tmp" ]; then
        dir="$(cat "$tmp")"
        command rm -f "$tmp"
        if [ -d "$dir" ]; then
            if [ "$dir" != "$(pwd)" ]; then
                cd "$dir"
            fi
        fi
    fi
}
bindkey -s '^o' lfcd^J

# Load Node Version Manager
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
