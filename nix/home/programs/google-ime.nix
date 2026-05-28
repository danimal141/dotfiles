{ config, dotfilesPath, ... }:

# Google Japanese Input (mozc) の keymap を declarative に持つ。
#
# 背景: Google IME の MS-IME default keymap は Ctrl+Space を IMEOnOff に
# 割り当てており、macOS 側 (`nix/darwin/keyboard.nix` の ⌘ Space 設定) と
# モディファイア衝突する。Kotoeri style は Ctrl+Space を bind せず、
# Hankaku/Zenkaku / Kanji / ON/OFF キーのみで IMEOnOff を扱うため衝突しない。
#
# mozc は keymap を `~/Library/Application Support/Google/JapaneseInput/
# config1.db` (binary protobuf) に持ち、watch path は存在しない。よって
# symlink を置くだけでは反映されず、Google IME 環境設定 → 一般 → キー設定
# の選択 → カスタム → 編集 → インポート で下記 path を 1 度指定する手動
# bootstrap が必要 (MCP server の `setup-mcp.sh` と同じ位置付け)。
#
# bootstrap 後はファイルが source of truth になり、編集 → 再 import で反映。
{
  home.file.".config/google-ime/keymap.tsv".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/google-ime/keymap.tsv";
}
