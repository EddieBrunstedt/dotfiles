function vault --description 'Mount/unmount the VeraCrypt shared vault at ~/vault'
    set -l container /data/shared/vault
    set -l mnt $XDG_RUNTIME_DIR/vault
    # Exists only while mounted.
    set -l link $HOME/vault

    switch "$argv[1]"
        case '' mount m
            if mountpoint -q $mnt
                echo "vault: already mounted → $link"
                return 0
            end
            if test -e $link; and not test -L $link
                echo "vault: $link exists and is not a symlink — refusing to touch it" >&2
                return 1
            end
            mkdir -p $mnt
            # Pre-answer everything but the password.
            if veracrypt --text --mount $container $mnt --pim 0 --keyfiles "" --protect-hidden no
                ln -sfn $mnt $link
                echo "vault: mounted → $link"
            else
                rmdir $mnt 2>/dev/null
                echo "vault: mount failed" >&2
                return 1
            end

        case off o umount unmount dismount d
            if mountpoint -q $mnt
                veracrypt --text --dismount $mnt; or return 1
            end
            test -L $link; and rm -f $link
            rmdir $mnt 2>/dev/null
            echo "vault: unmounted"

        case status s
            if mountpoint -q $mnt
                echo "vault: mounted at $mnt (→ $link)"
            else
                echo "vault: not mounted"
            end

        case '*'
            echo "usage: vault [mount | off | status]" >&2
            return 1
    end
end
