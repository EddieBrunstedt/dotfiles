function scrub --description 'Strip ALL metadata from image(s): scrub file...'
    if test (count $argv) -eq 0
        echo "usage: scrub IMAGE..." >&2
        echo "  writes a fully metadata-free copy as NAME-clean.EXT next to each file" >&2
        return 1
    end

    # -strip removes EXIF/IPTC/XMP/comments AND the ICC color profile.
    # -auto-orient first: stripping drops the EXIF orientation, so the pixels
    # must be rotated, or portrait phone photos come out sideways.
    for src in $argv
        if not test -f $src
            echo "scrub: no such file: $src" >&2
            continue
        end

        set -l dir (dirname $src)
        set -l base (path change-extension '' (basename $src))
        set -l ext (path extension $src)
        set -l dst "$dir/$base-clean$ext"

        magick $src -auto-orient -strip $dst
        and echo "scrubbed: $dst"
    end
end
