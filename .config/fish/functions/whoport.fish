function whoport --description "Show what process is listening on a TCP port"
    if test -z "$argv[1]"
        echo "usage: whoport <port>" >&2
        return 1
    end
    ss -ltnp "sport = :$argv[1]"
end
