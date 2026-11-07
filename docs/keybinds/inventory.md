# Keybinding inventory (2026-11-07)

A snapshot of every keybinding before the redesign. It lists defaults as well as overrides, since defaults are
where hidden conflicts are. Layers go top-down: a key claimed by a higher layer never reaches the layers
below it.

Versions: mango 0.18.2 (local build 5895a591), Ghostty 1.4.0, Neovim 0.12.6, fish 4.9.3 (+ fzf.fish),
yazi 26.9.1, Claude Code 2.1.319.

Sources: `.config/mango/config.toml`, `ghostty +list-keybinds`, `nvim_get_keymap()` from a headless Neovim
plus `~/.config/nvim/lua`, `bind` in an interactive fish, yazi's `keymap-default.toml` at v26.9.1 plus
`.config/yazi/keymap.toml`, Claude Code's default table plus `~/.claude/keybindings.json`.

Legend: **(d)** = program default, **(u)** = user config.

---

## Conflicts and oddities found

These are the actionable findings. Everything after this section is reference material.

### Keys a higher layer steals from a lower one

| Key | Taken by | Lost in | Notes |
|---|---|---|---|
| Alt+b / Alt+f | Ghostty (u) scroll page | fish (back/forward word), yazi input (word motion), readline everywhere (bash, python, psql…) | |
| Alt+d | Ghostty (u) half page down | fish (kill word), yazi input (kill word) | |
| Alt+e | Ghostty (u) scroll line down | fish `edit_command_buffer` | Your fish config notes this and moved `explain` to Ctrl+e. Alt+v still opens the editor in fish. |
| Alt+y | Ghostty (u) scroll line up | fish `yank-pop` | |
| Alt+1…9 | Ghostty (d) goto_tab | any app's Alt+digit | Only useful if you use Ghostty tabs. |
| Ctrl+Alt+arrows | mango (u) resizewin | Ghostty (d) goto_split, and any app | Ghostty's split navigation can never fire. |
| Alt+Tab, Alt+Shift+Tab, Alt+\`, Alt+Shift+\` | mango (u) overcircle / switcher | every app | Breaks the "Super = mango" rule. |
| Alt+x | mango (u) switch_proportion_preset | every app (Emacs/readline M-x) | Breaks the rule. |
| Alt+Shift+Return | mango (u) dwindle split direction | every app | Breaks the rule. |
| Ctrl+Alt+F1…F12 | mango (hardcoded) VT switch | everything | Can't be changed. Keep it in mind. |
| Ctrl+- | Ghostty (d) decrease_font_size | Claude Code `chat:undo` | Claude's undo probably still works on Ctrl+_. |
| Ctrl+= / Ctrl++ / Ctrl+0 | Ghostty (d) font size | apps | Rarely matters. |
| Ctrl+, | Ghostty (d) open_config | apps | Rarely matters. |
| Ctrl+Tab / Ctrl+Shift+Tab / Ctrl+PgUp/PgDn | Ghostty (d) tabs | apps | |
| Ctrl+Shift+Left/Right | Ghostty (d) previous/next tab | text selection in apps | mango's comment says "Ctrl+Shift+arrows belongs to text editing", but Ghostty takes Left/Right. |
| Ctrl+Shift+Up/Down | Ghostty (d) jump_to_prompt | apps | Useful with shell integration. |
| Shift+arrows, Shift+PgUp/PgDn/Home/End | Ghostty (d) selection / scrollback | apps | Standard terminal behavior. |

### Ghostty uses Super

Ghostty claims `super+ctrl+[` / `]` (goto_split), `super+ctrl+shift+arrows` (resize_split) and
`super+ctrl+shift+j` (write_screen_file). mango doesn't currently use any of these, so nothing is broken
today. But they break "Super = system", and the compositor would silently take them if mango ever bound
them.

### Inside one layer

| Layer | Key | What happens |
|---|---|---|
| fish | Ctrl+v | fzf.fish's variable search replaces fish's clipboard paste. Ctrl+Shift+V in Ghostty still pastes. |
| fish | Ctrl+y | Your accept-autosuggestion replaces vi-mode's `yank`. Intended. |
| fish | Ctrl+d | Your `delete-char` replaces `delete-or-exit`. Intended. |
| Neovim (oil buffers) | Ctrl+l | oil's default `refresh` replaces your window-right navigation in oil buffers. You already disabled oil's C-s/C-h/C-t for this reason. |
| Claude Code | Escape | Unbound in Chat, so `chat:cancel` is on Ctrl+k only. |

### Ergonomic and design notes

- **Super+Shift+l locks the screen**, one Shift away from Super+l (grow master).
- **Super+Shift is crowded**, with 15 launchers. Super+Shift+h/k/l are launchers, so moving windows had to go
  to Super+Shift+arrows instead of Super+Shift+hjkl.
- **mango supports keymodes** (`[bind.<mode>]` + `setkeymode`) and physical-key binds (`code:NN`). Both are
  options for the redesign: a launcher sub-mode, and layout-independent punctuation binds.
- **Scrolling uses vim-shaped keys in four places** with different modifiers. Ghostty scrollback is
  Alt+y/e/u/d/b/f, Claude Code fullscreen is Ctrl+y/e/b/f (u), and yazi and Neovim use Ctrl+d/u/b/f (d). These
  don't conflict (different layers), but it's worth making them consistent on purpose.
- **Ctrl+y means "accept"** in fish (u) and Neovim completion (d), but "scroll up" in Claude Code (u).
- **Neovim's only Alt keys** are mini.pick's `<M-CR>` (choose marked) and `<M-Space>` (refine marked). They
  work today.
- **Claude Code's Alt keys** are `meta+p` (model picker), `meta+o` (fast mode), `meta+t` (thinking) and
  `meta+w` (workflow keyword). They work today, but they're in the way if Ghostty takes more Alt keys.
- **Keys no app can rebind:** Ctrl+c, Ctrl+d (Claude Code), Ctrl+z (suspend), Ctrl+\ (SIGQUIT). Without the
  kitty keyboard protocol: Ctrl+m = Enter, Ctrl+i = Tab, Ctrl+[ = Esc, Ctrl+h = Backspace.

---

## Layer 0: system / hardcoded

| Key | Action |
|---|---|
| Ctrl+Alt+F1…F12 | VT switch (mango source, not configurable) |
| Caps Lock | Escape (xkb `caps:escape`) |
| XF86PowerOff | `lock-blank` (u, mango) |
| Print | `screenshot` (u, mango) |
| XF86AudioRaise/LowerVolume | wpctl ±5% (u, mango) |

## Layer 1: mango (all user-defined; the only built-in binds are the Ctrl+Alt+F-key VT switches)

### Super

| Key | Action |
|---|---|
| Super+Return | zoom (swap with master) **(fixed)** |
| Super+Shift+Return | ghostty **(fixed)** |
| Super+r | reload_config |
| Super+Shift+c | killclient |
| Super+p | rofi drun |
| Super+e | librewolf |
| Super+y | dir-menu |
| Super+q | power-menu |
| Super+v (press / release) | voxtype push-to-talk |
| Super+i / Shift+i / Ctrl+i | dunst act / close all / history |
| Super+Shift+n | dunst toggle |
| Super+j / k | focusstack next / prev |
| Super+h / l | mfact −/+ 0.05 |
| Super+space | focus_first_tiled |
| Super+Tab | previous tag |
| Super+\` | overview |
| Super+s / Shift+s / Ctrl+s | special tag: toggle / move to / move silently |
| Super+[ / ] | groupfocus prev / next |
| Super+Alt+arrows | groupjoin |
| Super+Alt+g | groupleave |
| Super+n | switch_layout |
| Super+t / Shift+t | right_tile / tile |
| Super+m | vertical_tile |
| Super+u | center_tile |
| Super+w / Shift+w | fair / vertical_fair |
| Super+d / Shift+d | right_deck / deck |
| Super+Shift+arrows | exchange_client |
| Super+Shift+space | togglefloating |
| Super+f / Shift+f | fullscreen / fake fullscreen |
| Super+a | maximize |
| Super+g | toggleglobal |
| Super+o | toggleoverlay |
| Super+\\ | Ghostty scratchpad |
| Super+Left / Right | view tag left / right |
| Super+Ctrl+Left / Right | move window to tag left / right |
| Super+1…9 | view tag |
| Super+Ctrl+1…9 | toggleview tag |
| Super+Shift+1…9 | move window to tag (silent) |
| Super+- / = / Shift+= | gaps −5 / +5 / toggle |
| Super+, / . | focus monitor left / right |
| Super+Shift+, / . | move window to monitor left / right |
| Super+Ctrl+Alt+arrows | scroller_stack |
| Super+LMB / RMB drag | move / resize |
| Super+scroll up / down | previous / next occupied tag |

### Super+Shift launchers

| Key | Launches |
|---|---|
| Super+Shift+a | wiremix (audio) |
| Super+Shift+e | emoji-menu |
| Super+Shift+g | whitetemp |
| Super+Shift+h | ghostty-shader-menu |
| Super+Shift+k | keyboard-layout-menu |
| Super+Shift+l | lock-screen |
| Super+Shift+m | system-menu |
| Super+Shift+p | ord_prompts |
| Super+Shift+r | ghostty-retro |
| Super+Shift+v | mullvad-menu |

### Non-Super (breaks the rule)

| Key | Action |
|---|---|
| Alt+Tab / Alt+Shift+Tab | overcircle next / prev |
| Alt+\` / Alt+Shift+\` | switcher all next / prev |
| Alt+x | switch_proportion_preset (scroller) |
| Alt+Shift+Return | dwindle toggle split direction |
| Ctrl+Alt+arrows | resizewin ±50 |

## Layer 2: Ghostty

### User

| Key | Action |
|---|---|
| Alt+y / Alt+e | scroll 1 line up / down |
| Alt+u / Alt+d | scroll half page up / down |
| Alt+b / Alt+f | scroll page up / down |
| Ctrl+Enter | unbound (default: toggle fullscreen) |

### Defaults still active

| Group | Keys |
|---|---|
| Clipboard | Ctrl+Shift+c / v, Ctrl+Insert, Shift+Insert (paste selection), Ctrl+Shift+a (select all) |
| Config | Ctrl+Shift+, (reload), Ctrl+, (open), Ctrl+Shift+p (command palette), Ctrl+Shift+i (inspector) |
| Font | Ctrl+= / Ctrl++ / Ctrl+- / Ctrl+0 |
| Scrollback | Shift+PgUp/PgDn/Home/End, Ctrl+Shift+Up/Down (jump to prompt), Ctrl+Shift+f (search), Esc (end search) |
| Selection | Shift+arrows |
| Screen dump | Ctrl+Shift+j (paste), Super+Ctrl+Shift+j (copy), Ctrl+Alt+Shift+j (open) |
| Windows | Ctrl+Shift+n (new), Ctrl+Shift+q (quit), Alt+F4 (close) |
| Tabs | Ctrl+Shift+t (new), Ctrl+Shift+w (close), Ctrl+Tab / Ctrl+Shift+Tab, Ctrl+PgUp/PgDn, Ctrl+Shift+Left/Right, Ctrl+Shift+PgUp/PgDn (move), Alt+1…8, Alt+9 (last) |
| Splits | Ctrl+Shift+o (right), Ctrl+Shift+e (down), Super+Ctrl+[ / ] (prev/next), Ctrl+Alt+arrows (goto; **dead, mango has it**), Super+Ctrl+Shift+arrows (resize), Ctrl+Shift+Enter (zoom) |

## Layer 3: apps inside the terminal

These never compete with each other because only one has focus at a time.

### fish (vi mode + fzf.fish)

Modifier binds in insert mode. Normal mode follows vi.

| Key | Action |
|---|---|
| Ctrl+y (u) | accept autosuggestion (insert + normal) |
| Ctrl+e (u) | `explain` (insert + normal) |
| Ctrl+d (u) | delete-char, never exits |
| Ctrl+r (u, fzf) | history search |
| Ctrl+t (u, fzf) | directory search |
| Ctrl+v (fzf d) | variable search (replaces paste) |
| Ctrl+Alt+l / p / s (fzf d) | git log / processes / git status |
| Ctrl+n (d) | accept autosuggestion |
| Ctrl+s (d) | pager search |
| Ctrl+x (d) | copy commandline to clipboard |
| Ctrl+space (d) | literal space without expanding abbreviation |
| Ctrl+Enter / Ctrl+j / Ctrl+m (d) | execute |
| Ctrl+k / Ctrl+u / Ctrl+w (d) | kill line / kill to start / kill path component |
| Ctrl+l (d) | clear screen |
| Ctrl+c (d) | clear commandline |
| Ctrl+Left/Right (d) | token back / forward |
| Alt+b/f, Alt+Left/Right (d) | word back / forward (or prevd/nextd on empty line); **Alt+b/f lost to Ghostty** |
| Alt+d (d) | kill word; **lost to Ghostty** |
| Alt+e / Alt+v (d) | edit commandline in $EDITOR; **Alt+e lost to Ghostty** |
| Alt+y (d) | yank-pop; **lost to Ghostty** |
| Alt+Up/Down, Alt+. (d) | history token search |
| Alt+Enter (d) | insert newline |
| Alt+h / w / l / o / p / s / # (d) | man page / whatis / list token / preview file / paginate / prepend sudo / toggle comment |
| Normal mode: y / p / P (u) | via system clipboard |

### Neovim (leader = Space)

Modifier keys (everything else is leader, `s` LSP, `[`/`]` bracketed, or `g` prefixes):

| Key | Mode | Action | Source |
|---|---|---|---|
| Ctrl+s | n, i, x, s | write buffer | keymaps.lua |
| Ctrl+s | c | toggle Flash search | flash.lua |
| Ctrl+h/j/k/l | n | window focus | keymaps.lua |
| Esc | n | nohlsearch | keymaps.lua |
| Esc Esc | t | leave terminal mode | keymaps.lua |
| Ctrl+Space / e / y / n / p / b / f / k | i | blink.cmp `default` preset: show / hide / accept / next / prev / scroll docs / signature | completion.lua |
| Ctrl+Space / e / y / n / p, Tab / S-Tab | c | blink.cmp cmdline | completion.lua |
| Tab / S-Tab | i, s | snippet jump | (d) |
| Ctrl+a / Ctrl+x / Ctrl+r / u | n | wrapped by mini.bracketed (still increment/decrement/redo/undo) | mini.lua |
| F1 / F2 / F3 / F5 / F7 | n | DAP step into / over / out / continue / UI | debug.lua |
| mini.pick (in picker) | | C-n/p move, C-f/b scroll, C-h/l scroll sideways, C-x mark, C-a mark all, C-s/C-v/C-t open in split/vsplit/tab, C-Space refine, **M-Space** refine marked, **M-CR** choose marked, Tab preview, S-Tab info | (d) |
| oil (in buffer) | | C-p preview, C-c close, **C-l refresh** (C-s/C-h/C-t disabled) | (d) |

Prefix families: `<leader>s` search, `<leader>h` git, `<leader>t` toggles, `<leader>x` diagnostics,
`<leader>y` yank, `<leader>f` format, `<leader>b/B` breakpoints, `<leader>q/l` quickfix/loclist,
`<leader>/` buffer lines, `<leader><Tab>` alternate buffer; `s` = LSP (sd/sD/si/sr/sR/st/ss/sS/sa/sn/sx/sh);
`S` Flash; `ys/ds/cs/gS` surround; `[`/`]` + b/d/f/i/j/l/o/q/t/u/w/x/y (mini.bracketed), c (gitsigns);
`-` oil; `gl` line diagnostics.

### Claude Code

User overrides (`~/.claude/keybindings.json`):

| Context | Key | Action |
|---|---|---|
| Chat | Escape | unbound (default: cancel) |
| Chat | Ctrl+k | cancel |
| Chat | Ctrl+y | unbound (default: switch to newer model) |
| Scroll | Ctrl+b / Ctrl+f | page up / down |
| Scroll | Ctrl+y / Ctrl+e | line up / down |

Defaults with modifiers (the ones that matter for conflicts):

| Key | Action |
|---|---|
| Ctrl+c / Ctrl+d | interrupt / exit (hardcoded) |
| Ctrl+t | todos |
| Ctrl+o | transcript |
| Ctrl+r | history search |
| Ctrl+] | open artifact |
| Ctrl+Shift+b | brief |
| Ctrl+Up/Down, Meta+Up/Down | diff file list |
| Shift+Tab | cycle mode |
| Meta+p / Meta+o / Meta+t / Meta+w | model picker / fast mode / thinking / workflow keyword |
| Ctrl+j | newline |
| Ctrl+Enter, Ctrl+x Ctrl+s | send now |
| Ctrl+x Enter | queue submit |
| Ctrl+x Ctrl+k | kill agents |
| Ctrl+_ / Ctrl+- | undo (Ctrl+- shadowed by Ghostty) |
| Ctrl+g, Ctrl+x Ctrl+e | external editor |
| Ctrl+s | stash |
| Ctrl+v | paste image |
| Ctrl+l | clear input |
| Ctrl+b, Ctrl+x Ctrl+b | background task |
| Ctrl+x Ctrl+a / Ctrl+x Tab | above-prompt panel toggle / focus |
| Ctrl+u / Ctrl+d, Ctrl+b / Ctrl+f, Ctrl+p / Ctrl+n | scroll (transcript / scroll views) |
| Ctrl+Shift+c | copy selection (fullscreen) |
| Shift+arrows / Shift+Home/End | extend selection (fullscreen) |

### yazi

User: Ctrl+n = drag out (dragon); `;` + letter = bookmarks; `q`, `gc`, `gd`, `gh` disabled.

Defaults with modifiers:

| Context | Key | Action |
|---|---|---|
| mgr | Ctrl+z | suspend |
| mgr | Ctrl+d / Ctrl+u / Ctrl+b / Ctrl+f | half page / page movement |
| mgr | Ctrl+a | select all |
| mgr | Ctrl+s | cancel search |
| mgr, tasks, etc. | Ctrl+c, Ctrl+[ | close / escape |
| input | Ctrl+a / e / b / f / h / d / k / w / u | readline-style editing |
| input | **Alt+b / Alt+f / Alt+d** | word back / forward / kill; **lost to Ghostty** |
| cmp | Alt+k / Alt+j (and Ctrl+p / Ctrl+n) | previous / next completion |
