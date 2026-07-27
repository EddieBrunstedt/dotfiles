# Custom key bindings. Calling fish_vi_key_bindings inside fish_user_key_bindings
# is the documented way to layer custom binds on top of vi mode, and keeps `bind`
# out of non-interactive shells.
function fish_user_key_bindings
    fish_vi_key_bindings
    bind ctrl-y accept-autosuggestion
    bind -M insert ctrl-y accept-autosuggestion

    # Visual-mode `y` copies to the system clipboard as well as fish's internal kill ring.
    # Normal-mode `p`/`P` paste from the system clipboard instead of the kill ring.
    bind -M visual -m default y fish_clipboard_copy fish_vi_yank_selection end-selection repaint-mode
    bind -M default p 'set -g fish_cursor_end_mode exclusive' forward-char 'set -g fish_cursor_end_mode inclusive' fish_clipboard_paste
    bind -M default P fish_clipboard_paste

    # Only delete char as per default, but do not exit shell if no text available
    bind -M default ctrl-d delete-char
    bind -M insert ctrl-d delete-char

    # Explain the typed command via LLM without running it (empty line = last
    # command). Note plain alt-e is swallowed by Ghostty (scrollback key).
    bind -M default ctrl-e explain
    bind -M insert ctrl-e explain
end
