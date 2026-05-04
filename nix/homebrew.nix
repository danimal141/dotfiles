{ ... }:

# Homebrew の宣言。Step B 時点では旧 `home/Brewfile` の brew/cask を全件
# そのまま移植している (Step C で CLI を Nix store に切り出す前段)。
#
# Step B の目的との対応:
#   * Brewfile + brew bundle では「宣言から外したら自動 uninstall」が無く、
#     dotfile を消しただけでは実機の brew は残る。`onActivation.cleanup`
#     を有効にすると `darwin-rebuild switch` 時に未宣言パッケージが自動で
#     uninstall されるため、git diff だけでパッケージ管理が完結する。
#   * tap / brew / cask の三層を flake.lock 配下で管理することで、
#     `darwin-rebuild --rollback` で「Homebrew インストール状態ごと」前世代
#     に戻せる。
{
  homebrew = {
    enable = true;

    onActivation = {
      # `brew update` を switch 時に走らせる。安定運用に入ったら off にして
      # 明示的な `brew update` だけにすると CI 様の決定性が増す。
      autoUpdate = true;

      # cleanup モード:
      #   "check"     — 未宣言パッケージを表示するだけ (uninstall しない)
      #   "uninstall" — 未宣言パッケージを自動 uninstall (= 宣言と完全同期)
      #   "zap"       — uninstall + 設定/データも削除 (危険)
      #
      # 初回は "check" で実害ゼロのまま「未管理パッケージのリスト」を
      # 確認する。意図しない uninstall が無いことを確認後に "uninstall"
      # に切り替えて宣言的同期を有効化する流れ。
      cleanup = "check";

      # `brew upgrade` は意図しないアップグレードでビルドを壊しがち。
      # バージョン更新は `nix flake lock --update-input` 相当のタイミングで
      # 明示的に実行する方針。
      upgrade = false;
    };

    # tap: nixpkgs / nix-homebrew では拾えない formulae の供給元。
    #   adoptopenjdk/openjdk — 旧 JDK build (cask の adoptopenjdk11 用)
    #   homebrew/cask-fonts  — font cask (font-jetbrains-mono 等)
    #   daipeihust/tap       — im-select の供給元 (IME 切り替え CLI)
    #   microsoft/apm        — APM CLI の供給元 (Step C で nix 化予定)
    taps = [
      "adoptopenjdk/openjdk"
      "homebrew/cask-fonts"
      "daipeihust/tap"
      "microsoft/apm"
    ];

    # brews: CLI ツール本体。Step B 時点では旧 Brewfile の brews を全件
    # 残置する (Nix store 化は Step C のスコープ)。
    brews = [
      "1password-cli"
      "FairwindsOps/tap/pluto"
      "age"
      "ansible"
      "argoproj/tap/argocd"
      "asdf"
      "automake"
      "azure-cli"
      "basictex"
      "bash-completion"
      "bat"
      "chezmoi"
      "chromium"
      "cloc"
      "cloudflared"
      "cmake"
      "codex"
      "coreutils"
      "cue"
      "curl"
      "direnv"
      "ffmpeg"
      "fujiwara/tap/tfstate-lookup"
      "gdb"
      "gh"
      "git"
      "gnu-sed"
      "googleworkspace-cli"
      "graphviz"
      "helm"
      "htop"
      "im-select"
      "imagemagick"
      "jq"
      "k1LoW/tap/tbls"
      "kayac/tap/ecspresso"
      "krew"
      "kubectx"
      "kustomize"
      "libmagic"
      "libpq"
      "llvm"
      "markdownlint-cli"
      "marp-cli"
      "mas"
      "mecab"
      "microsoft/apm/apm"
      "mutagen-io/mutagen/mutagen-compose"
      "mysql"
      "neovim"
      "pandoc"
      "parallel"
      "peco"
      "pipx"
      "pstree"
      "qemu"
      "readline"
      "redis"
      "repomix"
      "ripgrep"
      "ruby-build"
      "stern"
      "terminal-notifier"
      "the_silver_searcher"
      "tig"
      "tmux"
      "tmuxinator"
      "tree"
      "vim"
      "watch"
      "wget"
      "yarn"
      "yq"
      "yukiarrr/tap/ecsk"
      "zlib"
      "zsh"
      "zsh-autosuggestions"
      "zsh-completions"
      "zsh-syntax-highlighting"
    ];

    # casks: GUI アプリ。nix-homebrew (= Homebrew) 経由でしか配布されない
    # ものが大半なので、Step C でも引き続き brew 管理。
    casks = [
      "adoptopenjdk11"
      "avidemux"
      "brave-browser"
      "claude-code"
      "clipy"
      "cursor"
      "dash"
      "docker"
      "firefox"
      "font-jetbrains-mono"
      "font-source-code-pro"
      "font-source-han-code-jp"
      "freefilesync"
      "gcloud"
      "ghostty"
      "google-chrome"
      "google-japanese-ime"
      "handbrake"
      "intellij-idea"
      "kindle"
      "obsidian"
      "raycast"
      "react-native-debugger"
      "session-manager-plugin"
      "slack"
      "temurin"
      "the-unarchiver"
      "visual-studio-code"
      "vlc"
      "zoom"
    ];
  };
}
