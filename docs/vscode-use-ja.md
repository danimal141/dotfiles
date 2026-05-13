# VSCode Settings Management

[English](vscode-use.md) | 日本語

VSCode の `settings.json` / `keybindings.json` / extensions は home-manager
(`nix/home/programs/vscode.nix`) が darwin-rebuild の activation 経由で配置・
install する。`tools/vscode/` 配下に raw config を置き、`nix run .#switch`
1 発で同期される。

## ファイル構成

* `tools/vscode/settings.jsonc` — VSCode user settings (jsonc, `${HOME}`
  placeholder を含む)
* `tools/vscode/keybindings.jsonc` — keybindings (jsonc)
* `tools/vscode/extensions.txt` — install したい extension ID の一覧
* `tools/vscode/sync.sh` — extension sync utility (`--save` / `--status`)
* `nix/home/programs/vscode.nix` — 上記を読み込んで `~/Library/Application
  Support/Code/User/` 配下に配置する home-manager module

## 配置パターン

### settings.json

`builtins.readFile + builtins.replaceStrings` で `tools/vscode/settings.jsonc`
を読み込み、`${HOME}` を `/Users/${user}` に置換した上で `home.file."<path>".text`
で in-store 生成。

* jsonc コメント (`// ...`) は raw string として保持される
* `${user}` は `flake.nix` の `mkHost` の specialArgs 経由で host 別に解決
* 編集後は **`nix run .#switch` 必須** (text= による再 eval が要る)
* `~/Library/Application Support/Code/User/settings.json` は
  `/nix/store/...-home-manager-files/...` への symlink になる

### keybindings.json

`mkOutOfStoreSymlink` で `tools/vscode/keybindings.jsonc` への out-of-store
symlink を `~/Library/Application Support/Code/User/keybindings.json` に
配置。`${HOME}` 等の host 別解決が要らないため。

* 編集即反映: `nvim ~/Library/Application\ Support/Code/User/keybindings.json`
  で repo 内ファイルを直接編集できる。VSCode は file 変更を検知して reload
  (Cmd+R で明示 reload も可)
* `nix run .#switch` 不要

### extensions

`home.activation.vscodeExtensions` hook が:

1. `tools/vscode/extensions.txt` を 1 行ずつ走査
2. `code --list-extensions` の出力と比較
3. 未 install のものだけ `code --install-extension <id> --force` を発火

冪等で、毎回 `nix run .#switch` を打っても全件 install 済の状態では何も
しない。`code` コマンドが PATH に居ない環境 (= VSCode 未 install) では
skip して switch 全体は止めない。

社内 VPN の SSL inspection (中間者 CA) 対策で、hook 内で
`NODE_EXTRA_CA_CERTS=/etc/nix/ca-bundle.pem` を export する。bundle が無い
個人 Mac では未設定のまま (Node 既定の CA で動作)。

## 運用

### 初回セットアップ (新 Mac)

`setup.sh` 完走後、`darwin-rebuild` の activation 経由で settings /
keybindings / extensions すべてが自動配置される。手動で `apply-settings.sh`
等を呼ぶ必要はない。

### settings.json を編集する

```bash
$EDITOR tools/vscode/settings.jsonc
nix run .#switch
```

### keybindings.json を編集する

```bash
$EDITOR tools/vscode/keybindings.jsonc
# VSCode は自動 reload (もしくは Cmd+R で明示 reload)
```

`tools/vscode/keybindings.jsonc` を直接編集してもいいし、`~/Library/Application
Support/Code/User/keybindings.json` を VSCode 内から編集しても repo 内ファイル
が書き換わる (out-of-store symlink なので)。

### 新しい extension を追加する

```bash
# VSCode UI で extension を install (Cmd+Shift+X)
cd tools/vscode && ./sync.sh --save   # 実状態を extensions.txt に書き戻し
git diff extensions.txt               # 追加内容を確認して commit
```

次回 `nix run .#switch` で他 Mac でも自動 install される。

### sync 状態の確認

```bash
cd tools/vscode && ./sync.sh --status
```

VSCode に install されているが `extensions.txt` に無いもの / `extensions.txt`
にあるが install されていないもの / 同期済の一覧を表示。

### Custom Shortcuts (現 keybindings.jsonc の中身)

* **Cmd+Shift+L** (terminal focus 時): panel maximize toggle
* **Cmd+Shift+W**: Workspace Explorer focus
* **Cmd+Shift+C**: Explorer の全フォルダを collapse

新規 keybinding を追加する場合は VSCode の Keyboard Shortcuts editor
(Cmd+K Cmd+S) で構文を確認しながら `tools/vscode/keybindings.jsonc` に追記
する。jsonc なのでコメントが書ける。

## Platform 対応

macOS のみ対応。Linux 用の `~/.config/Code/User/` 経路は home-manager
module 側で扱っていない (このリポジトリ全体が macOS only 想定)。
