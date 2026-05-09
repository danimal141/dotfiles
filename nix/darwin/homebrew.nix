{ ... }:

# nix-darwin が管理する Homebrew (tap / brew / cask) の宣言。
#
# 設計の意図:
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
      # 明示的な `brew update` だけにすると CI ライクな決定性 (reproducibility)
      # が増す。
      autoUpdate = true;

      # cleanup モード:
      #   "none"      — 未宣言パッケージを無視 (uninstall も check も走らせない)
      #   "check"     — 未宣言パッケージがあれば activation を abort する
      #   "uninstall" — 未宣言パッケージを自動 uninstall (= 宣言と完全同期)
      #   "zap"       — uninstall + 設定/データも削除 (危険)
      #
      # "none" を採用: alfred / gcloud-cli / inkdrop など手動で入れた brew
      # を意図せず消したくないため。残したいものをすべて casks/brews に書き
      # 切ったタイミングで "uninstall" に切り替える。
      cleanup = "none";

      # `brew upgrade` は意図しないアップグレードでビルドを壊しがち。
      # バージョン更新は `nix flake lock --update-input` 相当のタイミングで
      # 明示的に実行する方針。
      upgrade = false;
    };

    # tap: nixpkgs / nix-homebrew では拾えない formulae の供給元。
    #   daipeihust/tap — im-select の供給元 (IME 切り替え CLI)
    #
    # font-* cask 群はかつて homebrew/cask-fonts tap に居たが、本家 homebrew/cask
    # に統合されたため tap 宣言は不要 (cask 名だけで resolve される)。
    taps = [
      "daipeihust/tap"
    ];

    # brews: Homebrew で運ぶ CLI / formulae。
    # 大半の CLI は `nix/packages.nix` (Nix store) 側に移してあり、ここに残すのは
    # Nix 経由では現実的でない or brew 側に置く方が扱いやすいものに絞る:
    #
    # * tap-only formulae        — FairwindsOps/pluto, fujiwara/tfstate-lookup,
    #                              k1LoW/tbls, kayac/ecspresso, mutagen-io/mutagen,
    #                              yukiarrr/ecsk, argoproj/argocd
    # * Apple / macOS 統合が強い  — ffmpeg, imagemagick, llvm, mas (basictex は cask 化したので casks 側)
    # * Node / Python 前提のツール — markdownlint-cli, marp-cli, repomix, pipx
    # * macOS-only ツール          — terminal-notifier, im-select
    # * shell 本体と plugin       — zsh, zsh-autosuggestions, zsh-syntax-highlighting,
    #                              zsh-completions (brew の方が起動が速い)
    # * secrets bootstrap         — age (1password-cli は cask 化したので casks 側)
    # * DB / dev サーバー          — mysql, redis, libpq, qemu
    brews = [
      "FairwindsOps/tap/pluto"
      "age"
      "ansible"
      "argoproj/tap/argocd"
      "automake"
      "azure-cli"
      "bash-completion"
      "cloudflared"
      "cmake"
      "codex"
      "ffmpeg"
      "fujiwara/tap/tfstate-lookup"
      "googleworkspace-cli"
      "im-select"
      "imagemagick"
      "k1LoW/tap/tbls"
      "kayac/tap/ecspresso"
      "krew"
      "libmagic"
      "libpq"
      "llvm"
      "markdownlint-cli"
      "marp-cli"
      "mas"
      "mecab"
      "mutagen-io/mutagen/mutagen-compose"
      "mysql"
      "pipx"
      "qemu"
      "readline"
      "redis"
      "repomix"
      "ruby-build"
      "terminal-notifier"
      "tmuxinator"
      "yarn"
      "yukiarrr/tap/ecsk"
      "zlib"
      "zsh"
      "zsh-autosuggestions"
      "zsh-completions"
      "zsh-syntax-highlighting"
    ];

    # casks: GUI アプリ。Homebrew 経由でしか配布されないものが大半なので
    # 引き続き brew 管理。
    casks = [
      "1password-cli"
      "avidemux"
      "basictex"
      "brave-browser"
      "chromium"
      "claude-code"
      "clipy"
      "cursor"
      "dash"
      "docker-desktop"
      "firefox"
      "font-jetbrains-mono"
      "font-source-code-pro"
      "font-source-han-code-jp"
      "freefilesync"
      "gcloud-cli"
      "ghostty"
      "google-chrome"
      "google-japanese-ime"
      "handbrake-app"
      "intellij-idea"
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
