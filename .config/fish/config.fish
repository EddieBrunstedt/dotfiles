if status is-interactive
    # Disable XON/XOFF flow control so Ctrl-S/Ctrl-Q are free.
    stty -ixon 2>/dev/null

    # API keys etc. from the login keyring (see `secret-env --help`).
    # Deliberately here and not in conf.d/ or ~/.profile: conf.d runs for
    # non-interactive fish too, and anything exported from ~/.profile is
    # picked up by uwsm's environment preloader and pushed into the systemd
    # and D-Bus activation environments — i.e. into every process in the
    # graphical session. Interactive shells only.
    secret-env export --fish | source

    # Rebind fzf.fish: Ctrl-T for file/dir picker; skip history binding so atuin keeps Ctrl-R.
    # Must run before atuin init so atuin's ctrl-r binding wins.
    fzf_configure_bindings --directory=ctrl-t --history=ctrl-r

    starship init fish --print-full-init | source
    zoxide init fish | source
    # navi widget fish | source
    # atuin init fish | source
    direnv hook fish | source

    abbr --add lsb 'lsblk -p -o NAME,TYPE,TRAN,HOTPLUG,SIZE,FSTYPE,LABEL,MOUNTPOINTS'
end
