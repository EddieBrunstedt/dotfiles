#
# ~/.bash_profile — bash login shells
#
# This file has to exist and has to source ~/.profile explicitly: bash reads
# only the FIRST of ~/.bash_profile, ~/.bash_login, ~/.profile that it finds, so
# having a .bash_profile at all means .profile is otherwise skipped entirely
# (which silently cost bash logins their $PATH and less(1) colours).

[ -f ~/.profile ] && . ~/.profile

[ -f ~/.bashrc ] && . ~/.bashrc
