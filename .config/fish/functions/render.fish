function render --description 'Render a file as nicely as possible in a new window'
    if test (count $argv) -eq 0
        echo "usage: render <file>" >&2
        return 2
    end

    set -l file $argv[1]
    if not test -e $file
        echo "render: no such file: $file" >&2
        return 1
    end

    set -l abs (path resolve $file)
    set -l ext (string lower (path extension $file))

    switch $ext
        case .md .markdown
            set -l tmpdir $XDG_RUNTIME_DIR
            test -n "$tmpdir"; or set tmpdir /tmp
            set -l out (mktemp -p $tmpdir --suffix=.html render-XXXXXX)
            pandoc --from gfm --to html --standalone --embed-resources \
                --css ~/.config/render/style.css \
                --metadata pagetitle=(path basename $file) \
                $abs --output $out
            or return
            chromium --app=file://$out --no-first-run &>/dev/null &
            disown
        case .html .htm
            chromium --app=file://$abs --no-first-run &>/dev/null &
            disown
        case ''
            echo "render: '$file' has no extension, don't know how to render it" >&2
            return 1
        case '*'
            echo "render: unsupported extension '$ext'" >&2
            return 1
    end
end
