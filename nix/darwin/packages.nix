{ pkgs, inputs, ... }:

# Nix store から供給する CLI ツール群。`flake.lock` で nixpkgs commit を pin
# しているため、別 Mac で `darwin-rebuild switch` してもバイト同一のバイナリ
# が入り、`darwin-rebuild --rollback` で CLI のバージョンも前世代に戻せる。
#
# Homebrew に残しているものと理由は `nix/homebrew.nix` の brews コメントに
# まとめている (shell bootstrap binaries, tap-only formulae, Apple 統合の
# 強い formulae 等)。
#
# PATH 競合に注意:
#   `zsh/.zshrc` で /run/current-system/sw/bin を /opt/homebrew/bin より前に
#   置いているため、Nix store と Homebrew の両方に同名バイナリがある場合は
#   Nix store 側が勝つ。下のリストに入れたものは brew 側からも消す
#   (= `nix/homebrew.nix` の brews から削除する) のが原則。
{
  environment.systemPackages = (with pkgs; [
    # core text & file utilities — どの言語でも使う薄い CLI 群。
    # Nixpkgs の追従ラグはほぼ無いので Nix 化のリスクが低い。
    bat
    coreutils       # GNU coreutils。macOS 標準の BSD 版より GNU 互換が優先
    fd
    fzf
    gnused          # macOS の sed は BSD 版でスクリプト互換性が低い
    jq
    ripgrep
    tig
    tree
    yq-go           # Go 実装の yq (Python 版より速い)

    # editors — vim / nvim は plugin が外部 git clone なので、本体だけ Nix で
    # 配ればよい。プラグイン管理は vim-plug が ~/.vim/plugged 以下で完結する。
    neovim
    vim

    # multiplexer
    tmux

    # git — flake.lock pin で「全マシン同一バージョン」が嬉しい代表例
    gh
    git

    # system inspection
    htop
    procps          # /proc 系 (watch / pgrep など) を macOS にも供給
    pstree

    # network
    curl
    wget

    # shell helpers
    direnv
    parallel

    # git pre-commit framework (Rust 実装の高速版、`pre-commit` の drop-in 互換)。
    # 本リポジトリの `.pre-commit-config.yaml` と secretlint hook を駆動して、
    # API key 等の誤コミットを物理的に block する防衛線。
    prek

    # docs / data
    cloc
    cue
    graphviz
    pandoc

    # kubernetes ecosystem — kubectl 本体は mise 管理。kubectx / kustomize /
    # helm / stern / krew は補助ツールとしてバージョン pin したいので Nix 側に置く。
    kubectx
    kustomize
    kubernetes-helm
    krew            # kubectl plugin manager (旧 brew、単独 Go binary)
    stern

    # build / system 補助 — 多くの言語ビルドで前提になる薄い CLI / lib。
    # 旧 brew から移植: Apple 特殊な機能を使っていない単独 binary / lib。
    age             # 暗号化 CLI (旧 brew、Go 単一 binary)
    automake        # GNU autotools
    bash-completion # bash の補完スクリプト群
    cloudflared     # Cloudflare Tunnel CLI (旧 brew、Go 単一 binary)
    cmake           # C/C++ build tool
    file            # libmagic 同梱 (旧 brew "libmagic" の代替)
    mecab           # 日本語形態素解析 (旧 brew、純 C++)
    zlib            # 圧縮 lib

    # Python tooling — Python runtime 自体は mise 配下、これは Python に
    # 依存しない (Rust 実装) project / package manager。pipx を置換する用途。
    uv              # `uv tool install <cli>` 系も含めて pip / pipx / venv を統合
  ]) ++ [
    # APM (microsoft/apm) は本家 nixpkgs に未収録。
    # numtide が `llm-agents.nix` flake で daily auto-update を提供しているので
    # それを inputs 経由で取り込む (`flake.nix` 参照)。
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.apm
  ];
}
