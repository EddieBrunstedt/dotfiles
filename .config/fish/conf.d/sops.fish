# Where sops finds the age identity that decrypts ~/.secret/*.sops.yaml.
# This exports a COMMAND, not a secret — safe in conf.d, safe under uwsm's
# environment preloader, safe in git.
set -gx SOPS_AGE_KEY_CMD "secret-tool lookup xdg:schema dev.dotfiles.age name sops"
