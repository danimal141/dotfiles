{ config, dotfilesPath, ... }:

# session-picker: Claude Code / Codex のセッションにタイトルを付けて
# fzf で検索・resume する CLI (`sr`)。
#
# * session-indexer.py が jsonl からタイトル索引
#   (~/.local/share/session-picker/index.jsonl) を作る。起点は Claude の
#   UserPromptSubmit hook (最初のプロンプト直後) と ExitPlanMode の
#   PostToolUse hook (plan H1 で上書き)、および `sr` 起動時の catch-up。
#   Codex には hook が無いので catch-up のみ。
# * ~/.local/bin は tools/zsh の PATH 設定で Homebrew より先に解決される。
{
  home.file = {
    ".local/bin/sr".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/session-picker/sr";
    ".local/bin/session-indexer.py".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/session-picker/session-indexer.py";
  };
}
