function killport --description "Kill the process listening on a TCP port (graceful; -f to force)"
    argparse f/force -- $argv
    or return 1

    if test -z "$argv[1]"
        echo "usage: killport [-f] <port>" >&2
        return 1
    end

    if set -q _flag_force
        fuser -k -KILL "$argv[1]/tcp"
    else
        fuser -k -TERM "$argv[1]/tcp"
    end
end
