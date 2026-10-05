function owns --description "Which pacman package owns a file?"
    argparse l/list -- $argv; or return

    if test (count $argv) -eq 0
        echo "usage: owns [-l/--list] <file|dir|command> ..." >&2
        return 2
    end

    for target in $argv
        set -l pkgs (pacman -Qoq -- $target 2>/dev/null)
        if test -z "$pkgs"
            pacman -Qo -- $target
            echo "Not owned by any installed package. Try: pacman -F $target"
            continue
        end

        # A directory can be owned by many packages
        for pkg in $pkgs
            pacman -Qi $pkg | grep -E '^(Name|Version|Description|Install Reason|Install Date)'
            if set -q _flag_list
                pacman -Ql $pkg
            else
                echo "Files owned: "(pacman -Qlq $pkg | count)"  (use owns -l for the list)"
            end
            echo
        end
    end
end
