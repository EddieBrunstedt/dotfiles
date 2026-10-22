#!/usr/bin/env bash
# Stop/Notification hook: notify unless this session's window is focused.
# Clicking the notification focuses the window.
input=$(cat)

transcript=$(jq -r '.transcript_path // empty' <<<"$input")
title=$(grep -hoE '"(customTitle|aiTitle)":"[^"]*"' "$transcript" 2>/dev/null | tail -1 | cut -d'"' -f4)
title=${title:-Claude Code}

# Ghostty's window title is the session title, possibly behind a spinner glyph.
window=$(mmsg get all-clients 2>/dev/null | jq -r --arg t "$title" '
  [.clients[] | select(.appid == "com.mitchellh.ghostty")
              | select(.title == $t or (.title | sub("^[^ ]+ "; "")) == $t)][0]
  // empty | "\(.id) \(.is_focused)"' 2>/dev/null)
[ "${window#* }" = true ] && exit 0
id=${window%% *}

# Untitled sessions all look alike, so name them by directory instead.
label=$title
[ "$label" = "Claude Code" ] && label="Claude Code · $(basename "$(jq -r '.cwd // empty' <<<"$input")")"

# First line of the reply, or the permission request in peach.
case $(jq -r .hook_event_name <<<"$input") in
  Notification)
    body=$(jq -r '.message // "Needs attention"' <<<"$input") colour='#fab387' ;;
  *)
    body=$(jq -r '.last_assistant_message // empty' <<<"$input" |
      sed -E '/^[[:space:]]*$/d; s/^[#>*+-]+ +//; s/\*\*|`//g' | head -1)
    [ ${#body} -gt 140 ] && body="${body:0:139}…"
    body=${body:-Done} colour= ;;
esac

# Escape body markup. Quoted, or bash 5.2 reads & as the match.
body=${body//'&'/'&amp;'} body=${body//'<'/'&lt;'} body=${body//'>'/'&gt;'}
[ -n "$colour" ] && body="<span foreground='$colour'>$body</span>"

# Detached so the hook returns while notify-send --wait waits for a click.
setsid bash -c '
  action=$(notify-send --wait -a Claude -i ~/.config/dunst/icons/claude.svg \
    ${1:+-A default=Focus} -- "$2" "$3")
  [ "$action" = default ] && mmsg dispatch focusid client,"$1" >/dev/null
' _ "$id" "$label" "$body" </dev/null >/dev/null 2>&1 &
