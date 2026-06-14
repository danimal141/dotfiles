---
paths:
  - "**/*.nix"
  - "**/flake.lock"
---

# Nix Build Rules

このリポジトリ (nix-darwin + home-manager dotfiles) の適用経路は
`nix run .#switch` (内部で `darwin-rebuild switch --flake ".#$(LocalHostName)"`)。

## デバッグフラグ

ビルド / eval エラーを追うときだけ付ける (通常は不要):

* `--print-build-logs` (`-L`): ビルド出力を常時表示 (通常は失敗時のみ)
* `--show-trace`: eval エラーの stack trace を表示

```bash
# 通常
nix run .#switch
nix build ".#darwinConfigurations.$(scutil --get LocalHostName).system" --no-link

# エラー調査時
nix build ".#darwinConfigurations.$(scutil --get LocalHostName).system" \
  --print-build-logs --show-trace
```

`switch` は activation で sudo (対話パスワード) を要する。非対話環境では
`nix build .#darwinConfigurations.<host>.system` で eval / build まで検証する。

## flake source と git

flake は **git-tracked なファイルのみ** source に含める。新規ファイルを
`builtins.readFile` / path literal で参照する前に必ず `git add` する
(未 tracked だと "is not tracked by Git" で eval が失敗する)。

## activation hook

* hook 本体は単一ファイルに inline 展開され `set -eu` で実行される。top-level の
  `return` は不正なので、early-exit は `exit` で書き hook 全体を subshell
  `( ... )` で囲む (export の漏れ防止も兼ねる)。
* activation の PATH は minimal。標準 CLI は `/run/current-system/sw/bin` 等を
  明示的に通すか、絶対パス (`${pkgs.coreutils}/bin/...`) で呼ぶ。
