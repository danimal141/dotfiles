# -------------------------------------
# Environment variable
# -------------------------------------
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# export EDITOR=$(brew --prefix nvim)
# export VISUAL=$(brew --prefix nvim)

# -------------------------------------
# path
# -------------------------------------
typeset -U path cdpath fpath manpath

# `N` means null glob in Zsh
path=(
  /usr/local/bin(N-/)
  /usr/local/sbin(N-/)
  /opt/homebrew/bin(N-/)
  /opt/homebrew/sbin(N-/)
  /usr/bin(N-/)
  $HOME/bin(N-/)
  $path
)

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

# -------------------------------------
# other settings
# -------------------------------------

# auto enter 'ls' after enter 'cd'
function chpwd() { ls -1 }

# tmuxinator
if [ -f ~/.tmuxinator/tmuxinator.zsh ]; then
  source ~/.tmuxinator/tmuxinator.zsh
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

# krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# peco
function peco-history-selection() {
  BUFFER=$(history 1 | sort -k1,1nr | perl -ne 'BEGIN { my @lines = (); } s/^\s*\d+\*?\s*//; $in=$_; if (!(grep {$in eq $_} @lines)) { push(@lines, $in); print $in; }' | peco --query "$LBUFFER")
  CURSOR=${#BUFFER}
  zle reset-prompt
}
zle -N peco-history-selection
bindkey '^R' peco-history-selection

# for zsh-completions
fpath=($(brew --prefix zsh-completions) $fpath)

# asdf
. $(brew --prefix asdf)/libexec/asdf.sh

# direnv
eval "$(direnv hook zsh)"

# llvm
export PATH="$(brew --prefix llvm)/bin:$PATH"

# psql
export PATH="$(brew --prefix libpq)/bin:$PATH"

# For M1Mac
# Fixing "The chromium binary is not available for arm64"
# https://www.broddin.be/fixing-the-chromium-binary-is-not-available-for-arm64/
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=`which chromium`
