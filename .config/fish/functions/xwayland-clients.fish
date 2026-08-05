function xwayland-clients --description "Show which applications are currently running on Xwayland"
    argparse h/help q/quiet p/pids -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: xwayland-clients [-q|--quiet] [-p|--pids]"
        echo
        echo "  (no flags)   human-readable report of X11 clients on Xwayland"
        echo "  -q, --quiet  no output; exit 0 if any app is on Xwayland, 1 if not"
        echo "  -p, --pids   print just the PIDs, one per line"
        return 0
    end

    set -l xpid (pgrep -x Xwayland | head -n1)
    if test -z "$xpid"
        set -q _flag_quiet; or echo "Xwayland is not running."
        return 1
    end

    # Display number Xwayland serves, e.g. :0 -> socket .X11-unix/X0
    set -l dpy (string replace -r '^.*:' '' -- (pgrep -a Xwayland | string match -r ':[0-9]+' | head -n1))
    test -n "$dpy"; or set dpy 0

    # Every process holding a connection to the X11 socket.
    # ss shows the client end of a unix socket as unnamed, so we match the
    # peer inode of each of Xwayland's X11 connections back to its owner.
    set -l clients (ss -xp 2>/dev/null | awk -v xpid="$xpid" -v dpy="$dpy" '
        {
            users = ""
            for (i = 9; i <= NF; i++) users = users (i > 9 ? " " : "") $i
            owner[$6] = users
            if ($5 ~ ("X11-unix/X" dpy "$") && users ~ ("pid=" xpid ",")) peer[$8] = 1
        }
        END {
            for (p in peer) {
                if (!(p in owner)) continue
                s = owner[p]
                while (match(s, /pid=[0-9]+/)) {
                    print substr(s, RSTART + 4, RLENGTH - 4)
                    s = substr(s, RSTART + RLENGTH)
                }
            }
        }' | sort -un)

    if test -z "$clients"
        set -q _flag_quiet; or echo "Xwayland is running (pid $xpid) but no application is connected to it."
        return 1
    end

    if set -q _flag_quiet
        return 0
    end

    if set -q _flag_pids
        printf '%s\n' $clients
        return 0
    end

    # PIDs that own a mapped toplevel X11 window, with their titles.
    # mango does not always keep _NET_CLIENT_LIST in sync, so union it with
    # _NET_CLIENT_LIST_STACKING.
    set -l titles
    set -l windowed
    if command -q xprop
        set -l wins (DISPLAY=:$dpy xprop -root _NET_CLIENT_LIST _NET_CLIENT_LIST_STACKING 2>/dev/null \
            | string match -r '0x[0-9a-f]+.*' | string split ', ' | string trim | sort -u)
        for w in $wins
            set -l props (DISPLAY=:$dpy xprop -id $w _NET_WM_PID WM_NAME 2>/dev/null)
            set -l wpid (printf '%s\n' $props | string match -r '_NET_WM_PID\(CARDINAL\) = (\d+)' | tail -n1)
            test -n "$wpid"; or continue
            set -l name (printf '%s\n' $props | string replace -rf '^WM_NAME[^=]*= "(.*)"$' '$1')
            set -a windowed $wpid
            set -a titles "$wpid	$name"
        end
    end

    echo "Xwayland: pid $xpid on display :$dpy"
    echo

    set -l shown
    echo "X11 windows:"
    if test -z "$windowed"
        echo "  (none — clients are connected but none have a mapped window)"
    end
    for pid in $clients
        contains $pid $windowed; or continue
        set -a shown $pid
        set -l name (ps -o comm= -p $pid 2>/dev/null; or echo "?")
        set -l title (printf '%s\n' $titles | string match -r "^$pid\t(.*)" | tail -n1)
        printf '  %-18s pid %-8s %s\n' $name $pid $title
    end

    set -l others
    for pid in $clients
        contains $pid $shown; or set -a others $pid
    end
    if test -n "$others"
        echo
        echo "Connected to Xwayland, no window of their own:"
        for pid in $others
            printf '  %-18s pid %-8s %s\n' (ps -o comm= -p $pid 2>/dev/null; or echo "?") $pid \
                (ps -o args= -p $pid 2>/dev/null | string sub -l 60)
        end
    end
    return 0
end
