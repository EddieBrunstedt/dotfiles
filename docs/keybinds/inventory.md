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
| Alt+b / Alt+f | Ghostty (u) scroll page | fish (back/forward word), yazi input (word motion), readline everywhere (bash, python, psql…) **Fixed: Ghostty gave up Alt.** |
| Alt+d | Ghostty (u) half page down | fish (kill word), yazi input (kill word) **Fixed: Ghostty gave up Alt.** |
| Alt+e | Ghostty (u) scroll line down | fish `edit_command_buffer` | Your fish config notes this and moved `explain` to Ctrl+e. Alt+v still opens the editor in fish. **Fixed: Ghostty gave up Alt.** |
| Alt+y | Ghostty (u) scroll line up | fish `yank-pop` **Fixed: Ghostty gave up Alt.** |
| Alt+1…9 | Ghostty (d) goto_tab | any app's Alt+digit | Only useful if you use Ghostty tabs. **Fixed: tabs unbound.** |
| Ctrl+Alt+arrows | mango (u) resizewin | Ghostty (d) goto_split, and any app | Ghostty's split navigation can never fire. **Fixed: mango gave up Alt.** |
| Alt+Tab, Alt+Shift+Tab, Alt+\`, Alt+Shift+\` | mango (u) overcircle / switcher | every app | Breaks the "Super = mango" rule. **Fixed: mango gave up Alt.** |
| Alt+x | mango (u) switch_proportion_preset | every app (Emacs/readline M-x) | Breaks the rule. **Fixed: mango gave up Alt.** |
| Alt+Shift+Return | mango (u) dwindle split direction | every app | Breaks the rule. **Fixed: mango gave up Alt.** |
| Ctrl+Alt+F1…F12 | mango (hardcoded) VT switch | everything | Can't be changed. Keep it in mind. |
| Ctrl+- | Ghostty (d) decrease_font_size | Claude Code `chat:undo` | Claude's undo probably still works on Ctrl+_. **Fixed: font size moved to view mode.** |
| Ctrl+= / Ctrl++ / Ctrl+0 | Ghostty (d) font size | apps | Rarely matters. **Fixed: font size moved to view mode.** |
| Ctrl+, | Ghostty (d) open_config | apps | Rarely matters. **Fixed: unbound.** |
| Ctrl+Tab / Ctrl+Shift+Tab / Ctrl+PgUp/PgDn | Ghostty (d) tabs | apps **Fixed: tabs unbound.** |
| Ctrl+Shift+Left/Right | Ghostty (d) previous/next tab | text selection in apps | mango's comment says "Ctrl+Shift+arrows belongs to text editing", but Ghostty takes Left/Right. **Fixed: tabs unbound.** |
| Ctrl+Shift+Up/Down | Ghostty (d) jump_to_prompt | apps | Useful with shell integration. |
| Shift+arrows, Shift+PgUp/PgDn/Home/End | Ghostty (d) selection / scrollback | apps | Standard terminal behavior. |

### Ghostty uses Super

**Fixed:** Ghostty no longer binds any Super keys.

### Inside one layer

| Layer | Key | What happens |
|---|---|---|
| fish | Ctrl+v | **Fixed:** variable search moved to Ctrl+Alt+v, so Ctrl+v pastes again. |
| fish | Ctrl+y | Your accept-autosuggestion replaces vi-mode's `yank`. Intended. |
| fish | Ctrl+d | Your `delete-char` replaces `delete-or-exit`. Intended. |
| Neovim (oil buffers) | Ctrl+l | **Fixed:** oil's Ctrl+l is disabled, so window navigation works in oil buffers too. |
| Claude Code | Escape | Unbound in Chat, so `chat:cancel` is on Ctrl+k only. |

### Ergonomic and design notes

- **Fixed:** Super+Shift+l locked the screen, one Shift away from Super+l. Lock now lives in launcher mode.
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

## Layer 1: mango (redesigned 2026-11-07)

Source of truth: `.config/mango/config.toml`. Everything is under Super:
- Super+key: act or focus.
- Super+Shift+key: take the window along.
- Super+Ctrl+key: the variant.

The only binds without Super are Print, the XF86 keys, and the hardcoded Ctrl+Alt+F-key VT switches.

| Keys | Action |
|---|---|
| Super+Return / Super+Shift+Return | swap with master / Ghostty |
| Super+Space | focus master (first tiled window) |
| Super+j/k | focus next / previous in the stack |
| Super+h/l | focus the left / right column |
| Super+Shift+j/k | move the window down / up the stack |
| Super+Shift+h/l | move the window left / right |
| Super+Ctrl+h/j/k/l | resize (tiled windows too) |
| Super+Alt+h/j/k/l | join group; Super+[ / ] focus within it, Super+Alt+g leave |
| Super+q / Super+Shift+q | close / force-kill |
| Super+f / Super+Shift+f | fullscreen / fake fullscreen |
| Super+Shift+Space, Super+g, Super+o | float, global, overlay |
| Super+s / Shift+s / Ctrl+s | special workspace: toggle / send / send silently |
| Super+1–9 / Shift / Ctrl / Ctrl+Shift | view / send / add to view / also show on that tag |
| Super+0, Super+Tab | all tags, previous tag |
| Super+Left/Right (+Shift, +Ctrl) | adjacent tag (take window along, skip empty tags) |
| Super+\` (+Shift), Super+Ctrl+\` (+Shift) | switcher, overcircle (hold Super, tap) |
| Super+Up / Super+Down | overview / overview with jump labels |
| Super+, / . (+Shift) | focus monitor / send window to monitor |
| Super+p, b, y, \\, v | rofi, browser, dir-menu, scratchpad, Voxtype (hold) |
| Super+i / Shift+i / Ctrl+i | notifications: act / close all / history |
| Super+r | reload config |
| Super+n | cycle right_tile → fair → right_deck |
| Super+x, then a key | launcher mode |
| Super+a, then a key | layout mode |

**Key modes.** A dunst card lists each mode's keys while the mode is open (`keymode-hint`). Each key works with
Super still held. Any key a mode doesn't use cancels it, and so does Esc.
- **Super+x launcher mode:** audio, emoji, keyboard layout, lock, system menu, do not disturb, prompts,
  power, retro, shader, white point, VPN.
- **Super+a layout mode:** the layouts (monocle on m), the number of master windows, gaps, scroller proportion.

## Layer 2: Ghostty (redesigned 2026-11-07)

Source of truth: `.config/ghostty/config`. It starts with `keybind = clear`, so every binding Ghostty has is
listed there. Ghostty only uses Ctrl+Shift and Shift+paging keys. Copy, Esc and Shift+arrows only take the
key when they can act; otherwise the key goes to the app.

| Keys | Action |
|---|---|
| Ctrl+Shift+c / v, Copy / Paste keys | copy (when there's a selection) / paste |
| Shift+Insert | paste the primary selection |
| Ctrl+Shift+a | select all |
| Shift+arrows | extend a selection (only when one exists) |
| Ctrl+Shift+f, Esc | search, close search (only while searching) |
| Shift+PgUp/PgDn/Home/End | scroll page / top / bottom |
| Ctrl+Shift+Up / Down | previous / next prompt |
| Ctrl+Shift+p, Ctrl+Shift+, , Ctrl+Shift+i | command palette, reload config, inspector |
| Ctrl+Shift+n | new window |
| Ctrl+Shift+j | paste the path of a file containing the screen's contents |
| Ctrl+Shift+Space | view mode (key table `view`) |

**View mode:**
- j/k scroll a line, d/u half a page, f/b a page.
- g/G go to the top / bottom.
- / searches, and n/N go to the next / previous match.
- y copies the selection.
- + (or =), - and 0 make the font bigger, smaller, or reset it.
- Esc, q or Ctrl+Shift+Space leave and jump to the bottom.
- Any other key leaves and still reaches the program.

**Removed:**
- the Alt scroll keys
- Alt+1–9 and Alt+F4
- font size on plain Ctrl, Ctrl+, , Ctrl+Tab, Ctrl+PgUp/PgDn and Ctrl+Insert
- all tab and split keys, including the Super and Ctrl+Alt ones
- the Super and Ctrl+Alt screen-dump variants
- Ctrl+Shift+q (quit, which closes every window of the shared Ghostty process)

## Layer 3: apps inside the terminal

These never compete with each other because only one has focus at a time.

### fish (vi mode + fzf.fish), reviewed 2026-11-07

Modifier binds in insert mode. Normal mode follows vi.

| Key | Action |
|---|---|
| Ctrl+y (u) | accept autosuggestion (insert + normal) |
| Alt+e (u) | `explain` (insert + normal), beside Alt+h and Alt+w |
| Ctrl+d (u) | delete-char, never exits |
| Ctrl+r (u, fzf) | history search |
| Ctrl+t (u, fzf) | directory search |
| Ctrl+Alt+v (fzf, u) | variable search |
| Ctrl+v (d) | paste |
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
| Alt+b/f, Alt+Left/Right (d) | word back / forward (or prevd/nextd on empty line) |
| Alt+d (d) | kill word |
| Alt+v (d) | edit commandline in $EDITOR (Alt+e is `explain`) |
| Alt+y (d) | yank-pop |
| Alt+Up/Down, Alt+. (d) | history token search |
| Alt+Enter (d) | insert newline |
| Alt+h / w / l / o / p / s / # (d) | man page / whatis / list token / preview file / paginate / prepend sudo / toggle comment |
| Normal mode: y / p / P (u) | via system clipboard |

### Neovim (leader = Space), redesigned 2026-11-07

Source of truth: `~/.config/nvim` (its own repo, `keybinds` branch). Neovim's defaults come first, then each
plugin's documented keys, then kickstart.nvim's conventions.

| Keys | Action | Origin |
|---|---|---|
| grn / gra / grx, K | rename / code action / codelens, hover | Neovim |
| grr / gri / grt / gO | references / implementation / type definition / document symbols, in mini.pick | Neovim keys |
| grd / grD / grR / gW | definition / declaration / references in this file / workspace symbols | kickstart |
| s / S | flash jump / flash treesitter (S only in normal and operator-pending) | flash README |
| r / R (operator-pending, visual), Ctrl+s (cmdline) | remote flash / treesitter search / toggle flash search | flash README |
| ys / ds / cs / yss, visual S | surround add / delete / replace / line, surround the selection | vim-surround |
| [ ] + b d q l t a (and capitals, Ctrl variants), [ / ] + Space | buffers, diagnostics, quickfix, loclist, tags, args, blank lines | Neovim |
| ]c / [c, ih | git hunks, hunk text object | gitsigns README |
| Ctrl+w d | diagnostic float (also opens on ]d / [d) | Neovim |
| Ctrl+h/j/k/l | window focus (oil no longer takes Ctrl+l) | kickstart |
| Ctrl+s | save (n, i, x); signature help is blink's Ctrl+k | user |
| Esc, Esc Esc (terminal) | clear search highlight, leave terminal mode | kickstart |
| aa / ii | mini.ai "next" text objects (an/in belong to Neovim 0.12) | user |
| blink: Ctrl+Space / e / y / n / p / b / f / k | completion: show / hide / accept / next / prev / scroll docs / signature | blink default |
| F5 / F1 / F2 / F3 / F7, leader b / B | debug continue / step into / step over / step out / UI, breakpoints | kickstart |

Leader groups:
- `s` search: files, grep (both with hidden variants), help, keymaps, diagnostics, resume, recent files,
  buffers, lines.
- `h` git: gitsigns README.
- `t` toggles: inlay hints, format on save, tailwind, zen, blame, word diff, equalize splits.
- `x` diagnostics to the loclist / quickfix list.
- `y` yank the buffer or the file path.
- Single keys: `f` format, `/` buffer lines, `<Tab>` alternate buffer, `q` / `l` quickfix / loclist.

Removed: the `s` LSP prefix, `gl`, visual `gS`, and mini.bracketed. Its `[`/`]` pairs duplicated
Neovim's, replaced `]t`, and wrapped `u` and `Ctrl+r`.

### Claude Code, reviewed 2026-11-07

User overrides (`.claude/keybindings.json`, stowed):

| Context | Key | Action |
|---|---|---|
| Chat | Escape | unbound (default: cancel) |
| Chat | Ctrl+k | cancel |
| Chat | Ctrl+y | unbound (default: switch to newer model) |
| Scroll | Ctrl+b / Ctrl+f | page up / down |
| Scroll | Ctrl+y / Ctrl+e | line up / down |
| Autocomplete | Ctrl+y / Ctrl+n / Ctrl+p | accept / next / previous (shared vocabulary; Tab and arrows still work) |

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
| Ctrl+_ / Ctrl+- | undo |
| Ctrl+g, Ctrl+x Ctrl+e | external editor |
| Ctrl+s | stash |
| Ctrl+v | paste image |
| Ctrl+l | clear input |
| Ctrl+b, Ctrl+x Ctrl+b | background task |
| Ctrl+x Ctrl+a / Ctrl+x Tab | above-prompt panel toggle / focus |
| Ctrl+u / Ctrl+d, Ctrl+b / Ctrl+f, Ctrl+p / Ctrl+n | scroll (transcript / scroll views) |
| Ctrl+Shift+c | copy selection (fullscreen) |
| Shift+arrows / Shift+Home/End | extend selection (fullscreen) |

### yazi, reviewed 2026-11-07 (no changes needed)

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
| input | Alt+b / Alt+f / Alt+d | word back / forward / kill |
| cmp | Alt+k / Alt+j (and Ctrl+p / Ctrl+n) | previous / next completion |
