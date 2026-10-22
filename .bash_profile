# bash skips ~/.profile when this file exists, so source it explicitly.
[ -f ~/.profile ] && . ~/.profile

[ -f ~/.bashrc ] && . ~/.bashrc
