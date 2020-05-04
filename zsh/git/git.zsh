# Configure git prompt.
source ~/.dotfiles/zsh/git/git-prompt.zsh
precmd () { __git_ps1 "%n" ":%~$ " "|%s" }
GIT_PS1_SHOWDIRTYSTATE="true"
GIT_PS1_SHOWSTASHSTATE="true"
GIT_PS1_SHOWUNTRACKEDFILES="true"
GIT_PS1_SHOWUPSTREAM="auto"
GIT_PS1_SHOWCOLORHINTS="true"
GIT_PS1_HIDE_IF_PWD_IGNORED="true"

# Configure git completion.
zstyle ':completion:*:*:git:*' script ~/.dotfiles/zsh/git/git-completion.bash
fpath=(~/.dotfiles/zsh/git $fpath)