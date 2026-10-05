function vault --description 'Mount/unmount the VeraCrypt shared vault at ~/vault'
    # The VeraCrypt container file (lives on the NTFS /data/shared partition).
    set -l container /data/shared/vault
    # Real mount point: per-session runtime dir, auto-wiped on logout/reboot.
    set -l mnt $XDG_RUNTIME_DIR/vault
    # Convenience symlink in $HOME; only exists while the vault is mounted.
    set -l link $HOME/vault

    switch "$argv[1]"
        case '' mount m
            if mountpoint -q $mnt
                echo "vault: already mounted → $link"
                return 0
            end
            # Never clobber a real file/dir that happens to sit at ~/vault.
            if test -e $link; and not test -L $link
                echo "vault: $link exists and is not a symlink — refusing to touch it" >&2
                return 1
            end
            mkdir -p $mnt
            # Prompts only for the volume password (and sudo); other questions
            # are pre-answered so it's a clean single prompt.
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
