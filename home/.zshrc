# -------------------------------------
# Environment variable
# -------------------------------------
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export EDITOR=/usr/local/bin/nvim
export VISUAL=/usr/local/bin/nvim

# export EDITOR=/usr/local/bin/vim
# export VISUAL=/usr/local/bin/vim
# export EDITOR=/usr/bin/vim
# export VISUAL=/usr/bin/vim

# -------------------------------------
# zsh options
# -------------------------------------

# for zsh-completions
fpath=(/usr/local/share/zsh-completions $fpath)

# complementation
autoload -U compinit
compinit -u

unsetopt auto_menu

setopt auto_pushd
setopt auto_cd
setopt correct
setopt nobeep
setopt prompt_subst
setopt ignoreeof
setopt no_tify
setopt hist_ignore_dups
setopt share_history

# -------------------------------------
# prompt
# -------------------------------------
autoload -U promptinit; promptinit
autoload -Uz colors; colors
autoload -Uz is-at-least
autoload -Uz vcs_info

zstyle ':vcs_info:*' actionformats '%F{5}(%f%s%F{5})%F{3}-%F{5}[%F{2}%b%F{3}|%F{1}%a%F{5}]%f '
zstyle ':vcs_info:*' formats       '%F{5}(%f%s%F{5})%F{3}-%F{5}[%F{2}%b%F{5}]%f '
zstyle ':vcs_info:(sv[nk]|bzr):*' branchformat '%b%F{1}:%F{3}%r'
precmd () { vcs_info }
PS1='%F{5}[%F{2}%n%F{5}] %F{3}%3~ ${vcs_info_msg_0_}%f%# '

# -------------------------------------
# key binding
# -------------------------------------
bindkey -d
# emacs
# bindkey -e

# viins
bindkey -v
bindkey -M viins '\er' history-incremental-pattern-search-forward
bindkey -M viins '^?'  backward-delete-char
bindkey -M viins '^A'  beginning-of-line
bindkey -M viins '^B'  backward-char
bindkey -M viins '^D'  delete-char-or-list
bindkey -M viins '^E'  end-of-line
bindkey -M viins '^F'  forward-char
bindkey -M viins '^G'  send-break
bindkey -M viins '^H'  backward-delete-char
bindkey -M viins '^K'  kill-line
bindkey -M viins '^N'  down-line-or-history
bindkey -M viins '^P'  up-line-or-history
bindkey -M viins '^R'  history-incremental-pattern-search-backward
bindkey -M viins '^U'  backward-kill-line
bindkey -M viins '^W'  backward-kill-word
bindkey -M viins '^Y'  yank

# -------------------------------------
# edit command line
# -------------------------------------
autoload -Uz edit-command-line
zle -N edit-command-line
# emacs
# bindkey '^xe' edit-command-line

# viins
bindkey -M vicmd i edit-command-line

# -------------------------------------
# alias
# -------------------------------------
alias grep="grep --color -n -I --exclude='*.svn-*' --exclude='entries' --exclude='*/cache/*'"

# ls
alias ls="ls -G" # color for darwin
alias l="ls -la"
alias la="ls -la"
alias l1="ls -1"

# tree
alias tree="tree -NC"

# pyenv
alias brew='env PATH="${PATH//$(pyenv root)\/shims:/}" brew'

# -------------------------------------
# other settings
# -------------------------------------

# auto enter 'ls' after enter 'cd'
function chpwd() { ls -1 }

# tmuxinator
if [ -f ~/.tmuxinator/tmuxinator.zsh ]; then
  source ~/.tmuxinator/tmuxinator.zsh
fi

# nvm
if [ -f ~/.nvm/nvm.sh ]; then
  source ~/.nvm/nvm.sh
fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then
  . "$HOME/google-cloud-sdk/completion.zsh.inc";
  . "$HOME/google-cloud-sdk/path.zsh.inc";
fi

# kubectl
[[ /usr/local/bin/kubectl ]] && source <(kubectl completion zsh)

# kubectx
alias kc="kubectx | peco | xargs kubectx"

# kubens
alias kns="kubens | peco | xargs kubens"

# peco
function peco-history-selection() {
  BUFFER=$(history 1 | sort -k1,1nr | perl -ne 'BEGIN { my @lines = (); } s/^\s*\d+\*?\s*//; $in=$_; if (!(grep {$in eq $_} @lines)) { push(@lines, $in); print $in; }' | peco --query "$LBUFFER")
  CURSOR=${#BUFFER}
  zle reset-prompt
}
zle -N peco-history-selection
bindkey '^R' peco-history-selection

# -------------------------------------
# path
# -------------------------------------
typeset -U path cdpath fpath manpath

path=(
  /usr/local/bin(N-/)
  /usr/local/sbin(N-/)
  /usr/bin(N-/)
  $HOME/bin(N-/)
  $path
)

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
# export PATH="$PYENV_ROOT/bin:$PATH"
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"'
eval "$(pyenv init -)"

# golang
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# rust
export PATH="$HOME/.cargo/bin:$PATH"

# deno
export PATH="$HOME/.deno/bin:$PATH"

# java
export _JAVA_OPTIONS="-Duser.language=en -Duser.country=US"

# Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

# wp-cli
export PATH="$HOME/.wp-cli/bin:$PATH"

# postgresql
export PGDATA=/usr/local/var/postgres

# rbenv
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
eval "$(rbenv init - zsh)"

# mysql
export PATH="/usr/local/opt/mysql@5.6/bin:$PATH"

# node
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
 export NVM_DIR="$HOME/.nvm"
  [ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# imagemagick@6
export PATH="/usr/local/opt/imagemagick@6/bin:$PATH"

# Added by serverless binary installer
export PATH="$HOME/.serverless/bin:$PATH"

# direnv
eval "$(direnv hook zsh)"
