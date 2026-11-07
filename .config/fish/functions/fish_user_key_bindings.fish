function fish_user_key_bindings
    fish_vi_key_bindings
    bind ctrl-y accept-autosuggestion
    bind -M insert ctrl-y accept-autosuggestion

    # y / p / P go through the system clipboard.
    bind -M visual -m default y fish_clipboard_copy fish_vi_yank_selection end-selection repaint-mode
    bind -M default p 'set -g fish_cursor_end_mode exclusive' forward-char 'set -g fish_cursor_end_mode inclusive' fish_clipboard_paste
    bind -M default P fish_clipboard_paste

    # Don't exit on an empty line.
    bind -M default ctrl-d delete-char
    bind -M insert ctrl-d delete-char

    # Explain the typed (or last) command, beside alt-h (man) and alt-w (whatis).
    # Its default, edit_command_buffer, stays on alt-v.
    bind -M default alt-e explain
    bind -M insert alt-e explain
end
