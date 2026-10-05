function remind --description "Schedule a desktop notification with at"
    if test (count $argv) -lt 2
        echo "usage: remind <message> <time>" >&2
        echo "  e.g. remind \"take out the trash\" \"10:00 2026-11-05\"" >&2
        echo "       remind \"stretch\" \"now + 30 minutes\"" >&2
        return 2
    end

    # Quote the message for /bin/sh, which is what at runs the job with
    set -l msg "'"(string replace -a "'" "'\\''" -- $argv[1])"'"

    # at saves the current environment and directory into the job. Keep only
    # what notify-send needs, and use $HOME so the job's cd can't fail later.
    # Extra args are joined into the time, so unquoted times work too
    echo "notify-send -u critical Reminder $msg" | env -i -C $HOME \
        HOME=$HOME PATH=/usr/bin LANG=$LANG \
        DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS \
        at $argv[2..-1] 2>&1 \
        | string match -v 'warning: commands will be executed using /bin/sh'
    return $pipestatus[2]
end
