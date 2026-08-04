if status is-interactive
    # Disable XON/XOFF flow control so Ctrl-S/Ctrl-Q are free.
    stty -ixon 2>/dev/null

    # fzf.fish: Ctrl-T for the file/dir picker (its default is Ctrl-Alt-F).
    # Ctrl-R for history is already fzf.fish's default, pinned here explicitly.
    fzf_configure_bindings --directory=ctrl-t --history=ctrl-r

    starship init fish --print-full-init | source
    zoxide init fish | source
    direnv hook fish | source

    abbr --add lsb 'lsblk -p -o NAME,TYPE,TRAN,HOTPLUG,SIZE,FSTYPE,LABEL,MOUNTPOINTS'
end
