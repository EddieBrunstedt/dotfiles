function render --description 'Render a file as nicely as possible in a new window'
    argparse -X 1 s/save f/force -- $argv
    or return 2

    if test (count $argv) -eq 0
        echo "usage: render [-s|--save [-f|--force]] <file>" >&2
        return 2
    end

    set -l file $argv[1]
    if not test -e $file
        echo "render: no such file: $file" >&2
        return 1
    end

    set -l abs (path resolve $file)
    set -l ext (string lower (path extension $file))
    # qutebrowser is handed a filesystem path, not a file:// URL: it resolves an
    # existing path with QUrl.fromLocalFile, which percent-encodes characters
    # that raw concatenation would leave for Qt to misparse ('#' as a fragment).
    set -l target

    switch $ext
        case .md .markdown
            set -l out
            if set -q _flag_save
                # --save puts the html beside the source instead of in the
                # runtime dir, under the source's real name, so the result is a
                # file worth handing to someone else. --embed-resources below
                # already makes it a single self-contained document.
                set out (path change-extension html $abs)
                if test -e $out; and not set -q _flag_force
                    echo "render: $out already exists, pass --force to overwrite" >&2
                    return 1
                end
            else
                # $XDG_RUNTIME_DIR is a tmpfs wiped at logout, so output never
                # reaches disk. One stable filename per source file rather than an
                # mktemp: re-rendering the same document overwrites its own output
                # instead of leaving another copy behind for the rest of the session.
                # The hash disambiguates same-named files in different directories.
                # No /tmp fallback: that directory is world-writable, and this
                # filename is predictable enough for another user to pre-plant a
                # symlink for pandoc to follow. Without a runtime dir there is no
                # session for the browser to open a window in anyway.
                if test -z "$XDG_RUNTIME_DIR"
                    echo "render: \$XDG_RUNTIME_DIR is unset, nowhere safe to write" >&2
                    return 1
                end
                set -l outdir $XDG_RUNTIME_DIR/render
                mkdir -p $outdir; or return
                set -l stem (path change-extension '' (path basename $abs) | string replace -ra '[^A-Za-z0-9._-]' '_')
                set -l hash (printf '%s' $abs | sha256sum | string sub -l 8)
                set out $outdir/$stem-$hash.html
            end
            pandoc --from gfm --to html --standalone --embed-resources \
                --css ~/.config/render/style.css \
                --metadata pagetitle=(path basename $file) \
                $abs --output $out
            or return
            set target $out
        case .html .htm
            if set -q _flag_save
                echo "render: --save only applies to markdown, '$file' is already html" >&2
                return 2
            end
            set target $abs
        case ''
            echo "render: '$file' has no extension, don't know how to render it" >&2
            return 1
        case '*'
            echo "render: unsupported extension '$ext'" >&2
            return 1
    end

    if set -q _flag_save
        echo $target
    end

    qutebrowser --basedir ~/.local/share/render-qb \
        --config-py ~/.config/render/qb.py \
        --target window $target &>/dev/null &
    disown
end
