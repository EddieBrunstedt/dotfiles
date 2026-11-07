# Keybinding contract (draft)

Who owns which keys. Every layer is redesigned against this page alone, so the layers can be done one at a
time without re-checking everything else. If a layer needs a key outside its namespace, change this page
first.

Layers, top-down: **mango** (compositor) → **Ghostty** (terminal) → **apps** (fish, Neovim, Claude Code,
yazi). A key claimed by a higher layer never reaches the layers below. Apps are siblings: only one has focus,
so they can't conflict with each other.

## 1. Ownership

| Keys | Owner | Notes |
|---|---|---|
| Anything with **Super** | mango + system | Window management, tags, launchers, menus, notifications, lock, power. No other layer binds Super. |
| Hardware keys (Print, XF86 media/power) | mango | |
| Ctrl+Alt+F1…F12 | kernel VT switch | Hardcoded in mango. Nobody binds these. |
| **Ctrl+Shift**+key | Ghostty | Ghostty's own defaults. Terminal apps can't normally tell Ctrl+Shift+x from Ctrl+x (only with the kitty keyboard protocol), so apps rarely use these keys. |
| Shift+PgUp/PgDn/Home/End | Ghostty | Standard terminal scrollback (Ghostty defaults). |
| **Everything else**: Ctrl, Alt, Ctrl+Alt, Shift, plain keys | apps | Mainly Ctrl and Alt. |

This replaces "Alt for the terminal". The comparison:

- **Alt** is the busiest modifier inside terminal apps. Fish, readline, yazi's input box and Claude Code's
  model/thinking toggles all use it by default. Giving Alt back to the apps brings back all their default
  Alt bindings.
- **Ctrl+Shift** is where Ghostty puts its own defaults, and apps barely use it, so the defaults stay
  intact.
- Ctrl+Shift is a two-modifier chord, but the terminal's own actions are rare. The one frequent one,
  scrolling, gets a mode (§3).

What changes as a result:

- mango gives up Alt+Tab, Alt+\`, Alt+x, Alt+Shift+Return and Ctrl+Alt+arrows.
- Ghostty gives up its Alt keys (scrolling, Alt+digits, Alt+F4), its plain-Ctrl keys (font size, Ctrl+,,
  Ctrl+Tab, Ctrl+PgUp/PgDn, Ctrl+Insert) and its Super keys. All of its tab and split bindings are removed,
  since you don't use them.

## 2. Fixed points

- Super+Return: zoom (swap with master).
- Super+Shift+Return: Ghostty.
- No app can rebind: Ctrl+c, Ctrl+d (Claude Code), Ctrl+z (suspend) and Ctrl+\ (SIGQUIT).
- Without the kitty keyboard protocol, some Ctrl keys are the same as other keys: Ctrl+m = Enter, Ctrl+i =
  Tab, Ctrl+[ = Esc and Ctrl+h = Backspace. Don't give these different meanings.
- Caps Lock = Escape (xkb).

## 3. Principles

### Everywhere

1. **Works on any keyboard.** Every binding works on a standard keyboard with no remapping. UHK layers can
   make things more comfortable but are never required.
2. **The US layout is the target.** Swedish and Danish are best effort. Punctuation binds may break there.
3. **Defaults win ties.** Only deviate from a program's default for a real ergonomic or conflict reason, and
   write the reason next to the binding.
4. **Disruptive actions are never one modifier away from frequent ones.** This covers lock, power, killing a
   window and closing everything.

### mango (Super)

5. **Modifiers carry meaning:**
   - Super+key: act on or focus something.
   - Super+Shift+key: the same thing, but take the window along (move, swap, send).
   - Super+Ctrl+key: a secondary variant (silent, toggle, resize).

   This applies to hjkl, arrows, digits and comma/period alike.
6. **hjkl and digits are only for navigation.** No launchers on them, with or without Shift.
7. **Only frequent launchers get direct keys.** The rest go behind a launcher keymode (Super+key, then a
   letter) or a rofi menu.

### Ghostty (Ctrl+Shift)

8. **Scrolling becomes a mode.** One Ctrl+Shift chord enters a Ghostty key table where plain vim keys scroll
   (j/k, u/d, b/f, g/G, / to search), and Esc or q leaves. Shift+PgUp/PgDn still work without the mode.

### Apps (Ctrl, Alt, plain keys)

9. **A shared vocabulary across apps** where the defaults already agree. Each app's defaults mostly follow it
   already. This is for memory, not to prevent conflicts:

   | Key | Meaning |
   |---|---|
   | Ctrl+n / Ctrl+p | next / previous item |
   | Ctrl+y | accept (completion, suggestion) |
   | Ctrl+d/u, Ctrl+f/b, Ctrl+e/y | scroll half page / page / line (in scroll contexts) |
   | Ctrl+r | history search |
   | Esc | cancel / back |

   Ctrl+y means both "accept" and "scroll line up", as it does in Vim. Context decides which one applies.
10. **Alt is for app-level actions that aren't text editing**, following each app's defaults (for example
    Claude Code's model picker and thinking toggle, and fish's man-page and editor keys).

## 4. Process

- **Order:** mango → Ghostty → apps (in any order).
- **Each step:** check new bindings only against this page, then update `inventory.md` for that layer.
- **Deviations from defaults:** keep a one-line reason next to the binding in the config itself.
