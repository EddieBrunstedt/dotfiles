if status is-interactive
    stty -ixon 2>/dev/null

    # brblack (the default) is also the selection background, so keep that dark.
    set -g fish_color_autosuggestion '#989898'

    fzf_configure_bindings --directory=ctrl-t --history=ctrl-r

    starship init fish --print-full-init | source
    zoxide init fish | source
    direnv hook fish | source

    abbr --add lsb 'lsblk -p -o NAME,TYPE,TRAN,HOTPLUG,SIZE,FSTYPE,LABEL,MOUNTPOINTS'
end
