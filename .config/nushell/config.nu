$env.config.cursor_shape.vi_insert = "line"
$env.config.cursor_shape.vi_normal = "block"
$env.config.edit_mode = 'vi'
$env.config.history.file_format = "sqlite"
$env.config.history.isolation = false
$env.config.rm.always_trash = true
$env.config.show_banner = false
$env.config.table.mode = "compact"

# aliases
alias hledger = hledger -s
alias ka = killall
alias lg = lazygit
alias ll = ls -l
alias man = batman
alias nvm = fnm
alias vim = nvim

# Secrets are not loaded into the environment. Use `sec NAME` on demand:
#   http get -H ["Authorization" $"Bearer (sec OPENAI_API_KEY)"] $url
# See ~/.secret/README.md

# enable Starship
mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

# enable Direnv
$env.config = {
  hooks: {
    pre_prompt: [{ ||
      if (which direnv | is-empty) { return }

      direnv export json | from json | default {} | load-env

      if 'ENV_CONVERSIONS' in $env and 'PATH' in $env.ENV_CONVERSIONS {
        $env.PATH = do $env.ENV_CONVERSIONS.PATH.from_string $env.PATH
      }
    }]
  }
}

# yazi jumper
def --env y [...args] {
  let tmp = (mktemp -t "yazi-cwd.XXXXXX")
  yazi ...$args --cwd-file $tmp
  let cwd = (open $tmp)
  if $cwd != "" and $cwd != $env.PWD {
    cd $cwd
  }
  rm -fp $tmp
}

# enable Zoxide
source ~/.zoxide.nu

# navi
source ($nu.default-config-dir | path join "navi-integration.nu")
