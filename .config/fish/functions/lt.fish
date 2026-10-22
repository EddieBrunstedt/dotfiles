# lt [depth] [eza flags/paths...]   e.g. `lt 2 -a`
function lt --description "eza tree helper: lt [depth] [native eza flags/paths]"
    set -l opts --tree --group-directories-first --icons=auto --time-style=long-iso
    if set -q argv[1]; and string match -qr '^\d+$' -- $argv[1]
        set -a opts --level $argv[1]
        set -e argv[1]
    end
    eza $opts $argv
end
