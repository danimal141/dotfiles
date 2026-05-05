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
#   `chezmoi/dot_zshrc.tmpl` で /run/current-system/sw/bin を /opt/homebrew/bin
#   より前に置いているため、Nix store と Homebrew の両方に同名バイナリが
#   ある場合は Nix store 側が勝つ。下のリストに入れたものは brew 側からも
#   消す (= `nix/homebrew.nix` の brews から削除する) のが原則。
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
    silver-searcher # `ag` 本体
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
    peco

    # docs / data
    cloc
    cue
    graphviz
    pandoc

    # kubernetes ecosystem — kubectl 本体は mise 管理。kubectx / kustomize /
    # helm / stern は補助ツールとしてバージョン pin したいので Nix 側に置く。
    kubectx
    kustomize
    kubernetes-helm
    stern
  ]) ++ [
    # APM (microsoft/apm) は本家 nixpkgs に未収録。
    # numtide が `llm-agents.nix` flake で daily auto-update を提供しているので
    # それを inputs 経由で取り込む (`flake.nix` 参照)。
    inputs.llm-agents.packages.${pkgs.system}.apm
  ];
}
