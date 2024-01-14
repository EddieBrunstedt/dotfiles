setopt shwordsplit

zle_highlight=('region:bg=168,fg=251')

# vi mode
bindkey -v
bindkey -v '^?' backward-delete-char

# Enable colors
autoload -U colors && colors

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

bindkey -s '^f' "br^J"

### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Plugins
zinit light zsh-users/zsh-autosuggestions
zinit load z-shell/H-S-MW
zinit load ellie/atuin
zinit load cjbassi/zsh-vi-mode-clipboard
zinit load zsh-users/zsh-syntax-highlighting

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


eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(navi widget zsh)"

source /usr/share/nvm/init-nvm.sh
source "$HOME/.config/aliasrc"
source $HOME/.config/broot/launcher/bash/br
