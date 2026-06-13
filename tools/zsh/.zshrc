# -------------------------------------
# Environment variable
# -------------------------------------
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

export EDITOR=nvim
export VISUAL=nvim

# -------------------------------------
# path
# -------------------------------------
typeset -U path cdpath fpath manpath

# `N` means null glob in Zsh — そのディレクトリが存在しないときは配列から落とす。
#
# 優先順:
#   1. /etc/profiles/per-user/$USER/bin
#      home-manager の user profile (`useUserPackages = true` の効果)。
#      starship など `programs.*.enable` で追加した user-level バイナリが
#      ここに置かれる。system 層 (/run/current-system/sw/bin) より先に置くのは
#      home-manager の user package が system package を override する慣習に倣う。
#   2. /run/current-system/sw/bin
#      Nix store (nix-darwin の `environment.systemPackages` 経由)。Homebrew
#      (/opt/homebrew/bin) より先に置くことで、両方に同名の CLI がある場合に
#      Nix 側が勝つ。`which git` 等が `/run/current-system/sw/bin/git` を返し、
#      `flake.lock` で pin されたバージョンが確実に走る。
#   3. /opt/homebrew/opt/<formula>/bin
#      Homebrew の keg-only / 個別 formula (llvm の clang、libpq の psql、
#      mysql@8.4 の mysql クライアント等) を expose する。Nix の **後** に置く
#      ことで、Nix 管理の同名 CLI があれば Nix 側が勝つ (= 「Nix 管理下の
#      ライブラリは Nix のパスから利用可能」を不変条件として保つ)。
#   4. $HOME/bin, $HOME/.local/bin
#      ユーザローカル installer (curl install.sh 系) が置く先。Homebrew の
#      通常 prefix (/opt/homebrew/bin) より **前** に置く。
#      理由: Claude Code / Codex を公式 native installer
#      (~/.local/bin/claude, ~/.local/bin/codex) で運用しているため、同名
#      binary を提供する brew (cask claude-code / formula codex,
#      /opt/homebrew/bin/...) より優先させる必要がある。副作用として、今後
#      ~/.local/bin に置かれる他のバイナリも
#      Homebrew 版より優先される。意図しない override を避けたいときは
#      ~/.local/bin に置かないか、brew 側の formula 名 (例: `gclaude` 等)
#      にリネームして解決する。
#   5. /usr/local/bin
#      Docker Desktop / VSCode / Cursor 等の installer が shim を置く先。
#      Apple Silicon Mac 前提なので Intel Homebrew prefix としては使わない。
#   6. /opt/homebrew/bin
#      Homebrew の通常 prefix (Nix 移行外の formulae / cask)。
#   7. mise activate (後段) が言語ランタイム shim を PATH 先頭に差し込む。
path=(
  /etc/profiles/per-user/$USER/bin(N-/)
  /etc/profiles/per-user/$USER/sbin(N-/)
  /run/current-system/sw/bin(N-/)
  /run/current-system/sw/sbin(N-/)
  /opt/homebrew/opt/llvm/bin(N-/)
  /opt/homebrew/opt/libpq/bin(N-/)
  /opt/homebrew/opt/mysql@8.4/bin(N-/)
  $HOME/bin(N-/)
  # $HOME/.local/bin: Claude Code / Codex の native binary
  # (~/.local/bin/{claude,codex}) が brew (claude-code cask / codex formula) の
  # /opt/homebrew/bin/... より勝つよう、Homebrew 群より前に置く。
  # 詳細は上のコメントの 4 番。
  $HOME/.local/bin(N-/)
  # /usr/local/bin: Docker Desktop / VSCode / Cursor などが shim を置く先。
  # Apple Silicon Mac でも Homebrew (= /opt/homebrew) 以外の installer が
  # 使うので残す (Intel Homebrew prefix としての役目はない)。
  /usr/local/bin(N-/)
  /opt/homebrew/bin(N-/)
  /opt/homebrew/sbin(N-/)
  /usr/bin(N-/)
  $path
)

# -------------------------------------
# plugins (via sheldon) — pre-compinit 段
# -------------------------------------
# sheldon plugin manager: ~/.config/sheldon/plugins.toml に宣言した plugin を
# 2 段階に分けて source する (詳細は plugins.toml のコメント参照)。
#
#   pre  — fpath を追加する plugin (zsh-completions)。compinit より「前」に
#          eval して fpath を整える必要がある。
#   post — compdef / zle widget を使う plugin (autosuggestions / syntax-
#          highlighting / git-fzf 等)。compinit より「後」に eval する必要が
#          ある (compdef は compinit 後でないと使えないため)。
#
# プラグイン用の環境変数は各 sheldon source の「前」に export する。plugin
# 側が source 時にデフォルト値で fix してしまうものがあるため。
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#565f89'
ENHANCD_FILTER='fzf:peco'
eval "$(sheldon --profile pre source)"

# -------------------------------------
# completion settings
# -------------------------------------
autoload -U compinit
compinit -u
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path ~/.zsh/cache

# -------------------------------------
# plugins (via sheldon) — post-compinit 段
# -------------------------------------
# zsh-syntax-highlighting は最後に source される (plugins.toml の末尾宣言)。
eval "$(sheldon --profile post source)"

setopt auto_pushd
setopt auto_cd
setopt correct
setopt nobeep
setopt prompt_subst
setopt ignoreeof
setopt no_tify
setopt hist_ignore_dups
setopt hist_ignore_all_dups
setopt share_history

# -------------------------------------
# prompt (starship)
# -------------------------------------
# starship バイナリと ~/.config/starship.toml は home-manager (`nix/home/`) で
# declarative に管理。`programs.starship.enableZshIntegration = false` にして
# eval 行はここに 1 行だけ手書きしている (zshrc を home.file で symlink 配置
# しているため home-manager の自動注入と衝突しないようにするため)。

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
# apm wrapper
# -------------------------------------
# apm install で git clone する時に必要な env を手動実行経路にも提供する。
# `nix run .#switch` の activation hook (nix/home/programs/apm.nix) と同等。
#   1. 社内 VPN SSL inspection 対策: /etc/nix/ca-bundle.pem を GIT_SSL_CAINFO
#      に inject。bundle が無い環境 (CI 等) では skip して無影響。
#   2. private repo 認証: gh auth token を GITHUB_APM_PAT に流す。
#      gh が無い / login していない環境では skip。
apm() {
  local -a inject=()
  [ -f /etc/nix/ca-bundle.pem ] && inject+=("GIT_SSL_CAINFO=/etc/nix/ca-bundle.pem")
  if command -v gh >/dev/null 2>&1; then
    local token
    token=$(command gh auth token 2>/dev/null)
    [ -n "$token" ] && inject+=("GITHUB_APM_PAT=$token")
  fi
  command env "${inject[@]}" apm "$@"
}

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

# kubectl (mise 管理経由で `~/.local/share/mise/installs/kubectl/.../bin/kubectl` を参照する)
command -v kubectl >/dev/null 2>&1 && source <(kubectl completion zsh)

# kubectx
alias kc="kubectx | fzf | xargs kubectx"

# kubens
alias kns="kubens | fzf | xargs kubens"

# krew
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# fzf key bindings (^R = fzf-history-widget, ^T = fzf-file-widget, M-c = fzf-cd-widget)
# fzf-share は Nix の fzf に同梱される helper で、share/fzf へのパスを返す。
# Nix store のパスは hash 込みで可変なので、fzf-share 経由で参照する。
if command -v fzf-share >/dev/null 2>&1; then
  source "$(fzf-share)/key-bindings.zsh"
  source "$(fzf-share)/completion.zsh"
fi

# 言語ランタイム管理は mise。global は `~/.config/mise/config.toml`
# (home-manager 経由で repo の mise/config.toml への symlink) を読み、
# project 個別は `<project>/mise.toml` または `.tool-versions` (asdf 互換)
# で上書きする。precompiled binary を優先利用するため Python の openssl 依存
# や Ruby の libyaml/readline で詰まらず新規 Mac での `mise install` が実用
# 時間で完走する。
#
# 配置の意図:
#   `mise activate zsh` は実行時点の PATH 先頭に shim ディレクトリを差し込む。
#   path-helper や上で組んだ /opt/homebrew / /usr/local の path 配列より
#   「後」に評価する必要がある (前に置くと shim が先頭に来た直後 path 配列で
#   上書きされ無効化される)。direnv より前に置くのは direnv が language
#   runtime を呼ぶケースを想定した慣習。
eval "$(mise activate zsh)"

# direnv
eval "$(direnv hook zsh)"

# starship prompt (config は ~/.config/starship.toml に home-manager 経由で
# 配置される)。mise / direnv より後ろに置く: prompt 系は他の PROMPT/PS1 設定
# を上書きするので、最後に init するのが慣習。
eval "$(starship init zsh)"

# llvm / libpq / mysql@8.4 の keg-only formulae 用 PATH は zshrc 冒頭の
# path=() 配列内で /opt/homebrew/opt/<formula>/bin として宣言済 (Nix の **後**)。
# `export PATH="$(brew --prefix <formula>)/bin:$PATH"` 形式は path 配列で
# 組んだ Nix 優先順序を後から壊すため使わない。

# For M1Mac
# Fixing "The chromium binary is not available for arm64"
# https://www.broddin.be/fixing-the-chromium-binary-is-not-available-for-arm64/
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=`which chromium`

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
