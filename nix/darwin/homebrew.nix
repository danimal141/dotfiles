{ ... }:

# nix-darwin が管理する Homebrew (tap / brew / cask) の宣言。
#
# 設計の意図:
#   * 常用する tap / brew / cask を nix-darwin 経由で宣言し、追加・削除の
#     レビュー単位を git diff に寄せる。
#   * `cleanup = "none"` で宣言外の手動 install は許容する。これは試用中の
#     brew / cask を残すための意図的な drift 許容であり、Homebrew prefix の
#     完全同期ではない。完全同期に寄せる場合は、まず `cleanup = "check"` で
#     未宣言 package を検出する。
#   * Homebrew の実体 version は上流 tap と `brew update` に依存するため、
#     Nix store CLI ほど強い rollback 再現性は期待しない。
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
      # "none" を採用: 試験的に手動で入れた brew / cask を意図せず消したく
      # ないため (= 「declarative に書く前の試用期間」を許容)。常用するものは
      # 下の casks / brews に書き切る。declared な entries だけが残る状態に
      # 揃った段階で "uninstall" に切り替えれば宣言と完全同期になる。
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
    # 大半の CLI は `nix/darwin/packages.nix` (Nix store) 側に移してあり、ここに
    # 残すのは Nix 経由では現実的でない or brew 側に置く方が扱いやすいものに絞る:
    #
    # * tap-only formulae        — FairwindsOps/pluto, fujiwara/tfstate-lookup,
    #                              k1LoW/tbls, kayac/ecspresso, mutagen-io/mutagen,
    #                              yukiarrr/ecsk, argoproj/argocd
    # * Apple / macOS 統合が強い  — ffmpeg, imagemagick, llvm, mas
    #                              (basictex は cask 化したので casks 側)
    # * Node / Python 前提のツール — markdownlint-cli, marp-cli
    # * macOS-only ツール          — terminal-notifier, im-select
    # * shell 本体                — zsh (login shell として brew 版を chsh)。
    #                              zsh プラグインは tools/sheldon/plugins.toml で管理
    # * DB / dev サーバー          — mysql, postgresql@17, redis, libpq, qemu
    # * Ruby ecosystem            — ruby-build (mise 経由 Ruby のビルド helper)
    # * cloud / automation CLI     — googleworkspace-cli, ansible, azure-cli
    # * build dependency           — readline
    # * nixpkgs 未収載             — herdr (AI coding agent 向け terminal workspace
    #                              manager)。更新は `brew upgrade herdr`
    #                              (herdr は Homebrew 管理下の binary を検出して
    #                              self-update を拒否し brew へ誘導する)
    #
    # codex は OpenAI 公式 native installer (~/.local/bin/codex) に移行したため
    # brews から外した (詳細は nix/home/programs/codex.nix)。cleanup="none" の
    # ため過去に brew install した実機の codex は残り得るが、PATH 順で native が
    # 勝つ。完全に消すなら手動で `brew uninstall codex` を実行する。
    brews = [
      "FairwindsOps/tap/pluto"
      "ansible"
      "argoproj/tap/argocd"
      "azure-cli"
      "ffmpeg"
      "fujiwara/tap/tfstate-lookup"
      "googleworkspace-cli"
      "herdr"
      "im-select"
      "imagemagick"
      "k1LoW/tap/tbls"
      "kayac/tap/ecspresso"
      "libpq"
      "llvm"
      "markdownlint-cli"
      "marp-cli"
      "mas"
      "mutagen-io/mutagen/mutagen-compose"
      "mysql"
      "postgresql@17"
      "qemu"
      "readline"
      "redis"
      "ruby-build"
      "terminal-notifier"
      "yukiarrr/tap/ecsk"
      "zsh"
    ];

    # casks: GUI アプリ。Homebrew 経由でしか配布されないものが大半なので
    # 引き続き brew 管理。
    casks = [
      "1password-cli"
      "avidemux"
      "basictex"
      "chromium"
      "claude-code"
      "clipy"
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
