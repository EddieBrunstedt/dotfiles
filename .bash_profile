#
# ~/.bash_profile — bash login shells
#
# Must source ~/.profile explicitly: bash reads only the FIRST of
# ~/.bash_profile, ~/.bash_login, ~/.profile that it finds, so having a
# .bash_profile at all means .profile is otherwise skipped entirely.

[ -f ~/.profile ] && . ~/.profile

[ -f ~/.bashrc ] && . ~/.bashrc
