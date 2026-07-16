{
  config,
  dotfilesPath,
  ...
}:

# herdr (AI coding agent 向け terminal workspace manager) の設定。
#
#   * binary は nixpkgs 未収載のため Homebrew 供給 (nix/darwin/homebrew.nix)。
#     更新は `brew upgrade herdr`。内蔵の `herdr update` は brew の Cellar を
#     直接上書きして manifest と drift するので使わない。
#   * config.toml は out-of-store symlink (配置パターン A)。live reload される
#     ので switch を挟まない。ただし herdr は onboarding の選択 /
#     `herdr channel set` / `herdr config reset-keys` で config.toml を書き換え、
#     書込は symlink 越しに repo へ届く。config.toml の `onboarding = false` で
#     自動発火する経路は塞いであり、残り 2 つは叩かない運用にする。
#   * agent 連携 (`herdr integration install`) は activation hook にしない。
#     生成物が tracked file なので hook にすると switch が git worktree を汚す
#     (既存 hook はいずれも repo の外にしか書かない)。commit すれば他マシンには
#     symlink 経由で渡るため毎 switch では no-op にしかならない。setup-mcp.sh /
#     Google IME keymap と同じ 1 度だけの手動 bootstrap (README-ja.md 参照)。
#     codex 側 hook script の symlink は ~/.codex の layout を持つ codex.nix が
#     宣言する (claude 側は claude.nix の hooks ディレクトリ symlink が運ぶ)。
#
# なお `herdr config check` は TOML の構文しか検証せず、未知のキーや不正な
# theme 名は素通りする。キーを増やすときは `herdr --default-config` の出力と
# 突き合わせること。

{
  home.file.".config/herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/herdr/config.toml";
}
