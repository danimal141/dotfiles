{
  config,
  dotfilesPath,
  ...
}:

# herdr (AI coding agent 向け terminal workspace manager) の設定。
#
#   * binary は nixpkgs 未収載のため Homebrew 供給 (nix/darwin/homebrew.nix)。
#   * config.toml は out-of-store symlink (配置パターン A)。live reload される
#     ので switch を挟まない。ただし herdr 自身が config.toml を書き換えうる
#     (onboarding の選択 / `herdr channel set` / `herdr config reset-keys`) ため、
#     書込は symlink 越しに repo へ届く。無条件に発火する onboarding だけは
#     config.toml の `onboarding = false` で塞ぎ、残り 2 つは叩かない運用にする。
#   * agent 連携 (`herdr integration install`) は activation hook にしない。
#     生成物が tracked file なので hook にすると switch が git worktree を汚す
#     (既存 hook はいずれも repo の外にしか書かない)。commit すれば他マシンには
#     symlink 経由で渡るため毎 switch では no-op にしかならない。
#     codex 側 hook script の symlink は ~/.codex の layout を持つ codex.nix が
#     宣言する (claude 側は claude.nix の hooks ディレクトリ symlink が運ぶ)。
#
# 運用 (更新 / 再 bootstrap の手順と注意) は docs/architecture-ja.md#herdr に
# 集約してある。

{
  home.file.".config/herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/herdr/config.toml";
}
