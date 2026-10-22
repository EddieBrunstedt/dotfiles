#!/usr/bin/env bash
# Stop / Notification hook: desktop notification for this session, unless its
# window is focused. Ghostty names each window after the session title, so
# match that against Mango's windows. Clicking the notification (or
# `dunstctl action`) focuses the window, switching tags if needed.
input=$(cat)

transcript=$(jq -r '.transcript_path // empty' <<<"$input")
title=$(grep -hoE '"(customTitle|aiTitle)":"[^"]*"' "$transcript" 2>/dev/null | tail -1 | cut -d'"' -f4)
title=${title:-Claude Code}

# The window title is the session title, possibly behind a spinner glyph.
window=$(mmsg get all-clients 2>/dev/null | jq -r --arg t "$title" '
  [.clients[] | select(.appid == "com.mitchellh.ghostty")
              | select(.title == $t or (.title | sub("^[^ ]+ "; "")) == $t)][0]
  // empty | "\(.id) \(.is_focused)"' 2>/dev/null)
[ "${window#* }" = true ] && exit 0
id=${window%% *}

# Untitled sessions all look alike, so name them by directory instead.
label=$title
[ "$label" = "Claude Code" ] && label="Claude Code · $(basename "$(jq -r '.cwd // empty' <<<"$input")")"

# The body is the first line of Claude's reply, or the permission request in
# waybar's peach, for anything waiting on you.
case $(jq -r .hook_event_name <<<"$input") in
  Notification)
    body=$(jq -r '.message // "Needs attention"' <<<"$input") colour='#fab387' ;;
  *)
    body=$(jq -r '.last_assistant_message // empty' <<<"$input" |
      sed -E '/^[[:space:]]*$/d; s/^[#>*+-]+ +//; s/\*\*|`//g' | head -1)
    [ ${#body} -gt 140 ] && body="${body:0:139}…"
    body=${body:-Done} colour= ;;
esac

# dunst parses markup in the body (not the summary). Quoted, or bash 5.2 reads
# the & in each replacement as the matched text.
body=${body//'&'/'&amp;'} body=${body//'<'/'&lt;'} body=${body//'>'/'&gt;'}
[ -n "$colour" ] && body="<span foreground='$colour'>$body</span>"

# --wait keeps notify-send around to print the chosen action; detach it so the
# hook returns at once.
setsid bash -c '
  action=$(notify-send --wait -a Claude -i ~/.config/dunst/icons/claude.svg \
    ${1:+-A default=Focus} -- "$2" "$3")
  [ "$action" = default ] && mmsg dispatch focusid client,"$1" >/dev/null
' _ "$id" "$label" "$body" </dev/null >/dev/null 2>&1 &
