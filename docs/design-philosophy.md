# 設計思想: nix-darwin + home-manager 一本化

このリポジトリは **nix-darwin + home-manager の二段構成**で運用している。
`~/` 配下の設定ファイルもすべて home-manager で declarative に配置するのが
現状の方針。

## TL;DR

新しい設定を追加するとき、置き場所の判断は **「raw text symlink で済むか、
それとも `programs.*` を使う動機があるか」** で切る。default は out-of-store
symlink で、以下のいずれかに当てはまるときだけ `programs.*` を選ぶ:

* **Nix で評価した値を設定内容に注入したい** — `specialArgs` 経由で host /
  user 別に流れてくる値を config 本文に埋めたい場合 (例: `programs.git` で
  `settings.user.name = gitName;` を specialArgs から差し込む)
* **binary 自体も home-manager の責務にしたい** — config を symlink で配置
  しても binary が無いと意味がないツール (例: `programs.mise.enable = true`
  で binary を `/etc/profiles/per-user/<user>/bin/` に配置。設定本体
  `~/.config/mise/config.toml` は下の out-of-store symlink で別途配置する
  dual 構成)
* **typed nested settings で書きたい** — TOML / YAML の括弧地獄を避けて
  Nix attrset の型補完で書きたい場合 (例: `programs.starship.settings` で
  prompt format を attrset 化)

上記いずれにも当てはまらないものは default の **out-of-store symlink** で
配置する。repo の `tools/<tool>/` 配下に raw text を置き、`home.file.<path>.source`
を `mkOutOfStoreSymlink` で symlink する (例: zshrc / tmux.conf / vimrc /
claude config / nvim / ctags / ghostty / markdownlint / apm / codex
AGENTS.md / mise/config.toml)。

例外として、内容を Nix で render したい (`${user}` などで host / user 別の
値を埋め込みたい) が `programs.<tool>` module が無い場合は
`home.file.<path>.text = ''...''` で in-store 生成する (例: codex
`config.toml` の wrapper 絶対パス)。詳細は下の「三つの配置パターン」 B 節
参照。

両者の決定的な違いは「編集してから反映までの操作」:

| 配置方式 | 反映操作 |
|---|---|
| `home.file` + `mkOutOfStoreSymlink` (out-of-store) | repo 内ファイルを編集 → 即反映 (`source ~/.zshrc` のような shell reload) |
| `home.file` + `text =` (in-store 生成) / `programs.<tool>.settings` | 編集 → `nix run .#switch` で再反映 |

`nix run .#switch` は flake.nix の `apps.aarch64-darwin.switch` で定義された
shell wrapper で、内部的には `darwin-rebuild switch --flake ".#$(scutil
--get LocalHostName)"` を呼ぶ (= 素の `darwin-rebuild` を直接打っても結果
は等価)。host 自動解決 / sudo 先行プロンプト / nom (interactive 時のみ) 連携を
1 ヶ所に集約してある。詳細は README の「日常運用」セクション参照。

`mkOutOfStoreSymlink` を使う場合、`~/.zshrc` は repo 内ファイルへの symlink
になるので、`vim ~/.zshrc` を開けば repo を直接編集している状態になる。
編集 → shell reload (`source ~/.zshrc`) で即反映、`nix run .#switch`
を介さない短い iteration cycle が成立する。

## ディレクトリ構造

```
dotfiles/
├── flake.nix                      # darwinConfigurations.{work,personal,...}
├── flake.lock
├── nix/
│   ├── darwin/                    # nix-darwin (system 層)
│   │   ├── default.nix            # 配下の 6 ファイルを imports
│   │   ├── defaults.nix           # system.defaults.* (Dock / Finder /
│   │   │                           # NSGlobalDomain / trackpad / WindowManager
│   │   │                           # / menuExtraClock / CustomUserPreferences)
│   │   ├── keyboard.nix           # system.keyboard (CapsLock → Control HID
│   │   │                           # remap) / launchd.user.agents (login 時
│   │   │                           # hidutil 再適用) / system.activationScripts.
│   │   │                           # postActivation (AppleSymbolicHotKeys の
│   │   │                           # targeted update)
│   │   ├── nix-daemon.nix         # nix.settings + nix.gc +
│   │   │                           # environment.variables (SSL CA bundle 等)
│   │   ├── system.nix             # primaryUser / users.users / programs.zsh
│   │   │                           # disable / system.stateVersion (residual)
│   │   ├── packages.nix           # Nix store CLI
│   │   ├── homebrew.nix           # GUI cask + tap-only / Apple-integrated formulae
│   │   └── hosts/
│   │       ├── work.nix           # networking.hostName 強制 (per host)
│   │       └── personal.nix
│   └── home/
│       ├── default.nix            # imports + home.{stateVersion,username,homeDirectory}
│       └── programs/              # 1 ファイル 1 ツール
│           ├── zsh.nix            # ~/.zshrc symlink
│           ├── git.nix            # programs.git + ignores + includeIf
│           ├── tmux.nix           # ~/.tmux.conf, ~/.tmux_start_dir, ~/.local/bin/tmux-start
│           ├── vim.nix            # ~/.vimrc + サブディレクトリ symlink (plugged/ 除く)
│           ├── nvim.nix           # ~/.config/nvim/* (vim と coc-settings 共有)
│           ├── claude.nix         # ~/.claude/* (動的領域除く)
│           ├── codex.nix          # ~/.codex/* (config.toml は text 生成 / wrapper は symlink /
│           │                        # AGENTS.md は tools/claude/CLAUDE.md への out-of-store symlink)
│           ├── apm.nix            # ~/.apm/* + home.activation.apmInstall hook
│           ├── mise.nix           # programs.mise + ~/.config/mise/config.toml + miseTrust hook
│           ├── markdownlint.nix   # ~/.markdownlint.jsonc symlink
│           ├── starship.nix       # programs.starship.settings
│           ├── ghostty.nix        # ~/Library/Application Support/com.mitchellh.ghostty/config
│           ├── ctags.nix          # ~/.ctags.d/exclude.ctags
│           └── vscode.nix         # ~/Library/Application Support/Code/User/{settings,keybindings}.json + extensions hook
├── tools/                         # ツール毎の raw text dotfile (`nix/home/programs/*.nix` が consume)
│   ├── zsh/.zshrc
│   ├── tmux/{.tmux.conf, .tmux_start_dir, bin/tmux-start}
│   ├── vim/{.vimrc, .vim/{coc-settings.json, filetype.vim, autoload, colors, ftdetect, ftplugin}}
│   ├── nvim/{init.vim, lua/telescope-config.lua}
│   ├── claude/{CLAUDE.md, settings.json, mcp-servers.yaml, hooks/, rules/, skills/.gitignore, .env.example, setup-mcp.sh}
│   ├── codex/{wrappers/gemini-mcp.sh, .env.example}
│   ├── apm/{apm.yml, apm.lock.yaml, .gitignore}
│   ├── mise/config.toml
│   ├── markdownlint/.markdownlint.jsonc
│   ├── ghostty/config
│   ├── ctags/exclude.ctags
│   └── vscode/{settings.jsonc, keybindings.jsonc, extensions.txt, sync.sh}
├── setup.sh                       # 初回 bootstrap
└── docs/                          # 設計ドキュメント
```

## 三つの配置パターン

### A. out-of-store symlink (大半の dotfile)

`home.file."<path>".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/<tool>/<file>"` の形。
repo の絶対 path を user 変数 (`/Users/${user}/Documents/dev/dotfiles`) で構築し、
`~/<path>` から repo を直接 symlink する。

* **編集体験**: `vim ~/.zshrc` で repo 内ファイルを開いて編集 → `source ~/.zshrc` で即反映
* **`nix run .#switch` 不要**: ファイルの中身変更だけなら symlink target の中身が変わるだけ
* **使い所**: zsh / tmux / vim / nvim / claude (CLAUDE.md / settings.json /
  hooks / rules / mcp-servers.yaml) / codex AGENTS.md / apm (apm.yml /
  apm.lock.yaml / .gitignore) / tools/mise/config.toml / markdownlint /
  ghostty / ctags

### B. text 生成 (text =)

`home.file."<path>".text = ''...''`。home-manager が Nix store に実体ファイルを
焼き、`~/<path>` をそこへの symlink にする。

* **使い所**: Nix の `${user}` などで内容を user/host 別にレンダリングしたい場合 (例: codex
  `config.toml` の wrapper 絶対パス)
* **トレードオフ**: 編集には `nix/home/programs/<tool>.nix` の `text = ''...''` を書き換え
  → `nix run .#switch` が必要

### C. declarative module (programs.\*)

`programs.<tool>.{enable, settings, ...}`。home-manager が module を解釈して
適切な path に出力する。

* **使い所** (TL;DR の 3 動機のいずれかに当てはまる場合):
  * Nix で評価した値を config に注入 (例: `programs.git.settings.user.name = gitName;`)
  * binary 自体も home-manager の責務にする (例: `programs.mise.enable`。
    設定 `~/.config/mise/config.toml` は raw text symlink との dual 構成)
  * typed nested settings で書きたい (例: `programs.starship.settings`)
* **トレードオフ**: 同上 (`nix run .#switch` 必要)。raw text と比較して編集即反映の
  cycle が遅い

## 動的領域の扱い

ツールが自走で書き換える領域 (Claude Code の `~/.claude/projects/`, codex の
`~/.codex/sessions/`, vim-plug の `~/.vim/plugged/`, apm の `~/.apm/apm_modules/`)
は **home.file 対象外**として ~/ 配下に普通の mutable directory として残す。
home-manager は配置に介入しない。

これにより:

* ツール側の自走書き換えと home-manager の symlink 配置が衝突しない
* `nix run .#switch` 後にも user data が消えない
* repo に dynamic な内容が流入しない (= git status が綺麗)

## secrets 設計

repo は public 想定で運用しているため secrets を tracked file に置かない。
注入経路は 3 種類:

* **wrapper script + `~/.codex/.env`** (codex の `GEMINI_API_KEY`):
  `~/.codex/.env` (gitignore 不要 = repo 外配置) を user が手動配置し、
  wrapper (`tools/codex/wrappers/gemini-mcp.sh`) が起動時に source して child
  process に env として inject する。`tools/codex/.env.example` を template
  として tracked。
* **MCP server 登録 + `tools/claude/.env`** (`GITHUB_PERSONAL_ACCESS_TOKEN` /
  `GEMINI_API_KEY` / `BRAVE_API_KEY`):
  `tools/claude/setup-mcp.sh` が repo 内の `tools/claude/.env` を source して
  `claude mcp add` の env として渡す。`~/.claude/.env` ではなく **repo 内の
  `tools/claude/.env`** を読む点に注意 (= setup-mcp.sh が
  `cd tools/claude && ./setup-mcp.sh` で実行されることを前提に
  `${SCRIPT_DIR}/.env` を見ている)。`tools/claude/.env` は gitignore で除外、
  `tools/claude/.env.example` を template として tracked。
* **手書き dispatcher + overrides** (work git identity):
  repo の `programs.git.includes` は `~/.gitconfig.local` (user 手書き、
  repo 外) を unconditional に include するだけで、条件分岐 (どの remote
  URL pattern で identity を切り替えるか) と上書き値 (`~/.gitconfig.work`
  の `[user]` ブロック) はどちらも user 側で記述する。所属組織名や業務
  メールが repo に出ない構成。手順は README 参照。

`.env` 系は repo に `.env.example` のみ tracked、新マシンでは copy + 値埋めの
手動 1 ステップ。将来 sops-nix / agenix で declarative にしたければ独立 task。

## ホスト別分岐

work / personal で `user` (macOS account name) と git identity (`gitName` /
`gitEmail`) が違うので、`flake.nix` の `hosts` attrset で 1 entry / host
として宣言:

```nix
hosts = {
  "work"     = { user = "hideaki.ishii"; gitName = "danimal141"; gitEmail = "..."; };
  "personal" = { user = "danimal141";    gitName = "danimal141"; gitEmail = "..."; };
};
```

`mkHost` がこれらを `specialArgs` 経由で全モジュール (system / home /
hosts/<hostname>.nix) に流す。マシン追加は 1 entry 足すだけ。

`networking.hostName` は `nix/darwin/hosts/<hostname>.nix` で強制 (IT 部門が
払い出す hostname を上書き)、`scutil --get LocalHostName` を flake host の
真実源にする。

## apply 時の declarative 副作用

`darwin-rebuild` (= `nix run .#switch`) の activation 経路で実行する
副作用が現状 4 つ。それぞれ責務と発火タイミングが違う:

### home-manager `home.activation.<name>`

home-manager のユーザ activation 経路。`activate` の `writeBoundary` 後に
ユーザ権限で走る。

* `apmInstall` (apm.nix): `~/.apm/apm.yml` の sha256 を `~/.apm/.apm.yml.hash`
  に保存し、差分があるときだけ `apm install --target claude` を実行 (冪等)
* `miseTrust` (mise.nix): repo path の `tools/mise/config.toml` を mise の trust
  store に登録 (out-of-store symlink で外部 path 扱いになる対策)

両者とも `pkgs.<tool>` で binary パスを直接呼ぶ (PATH 依存を避ける)。
apm は nix-darwin の `environment.systemPackages` 経由で居るので
`/run/current-system/sw/bin` への PATH export を追加している。

### system `system.activationScripts.postActivation`

nix-darwin の system activation 経路で root 権限で走る (`launchctl asuser`

* `sudo --user=...` で対象ユーザに切り替えながら個別コマンドを発行する形)。

* 入力ソース切替 shortcut (`AppleSymbolicHotKeys` の ID 60 / 61) を
  `defaults write -dict-add` で targeted update。`AppleSymbolicHotKeys`
  dict 全体は Spotlight / Mission Control / Screenshot 等が同居するため、
  `system.defaults.CustomUserPreferences` で書くと dict ごと上書き
  してしまう。それを避けるため per-key の dict-add を選択している。
  詳細は `nix/darwin/keyboard.nix` の該当セクション。

### `launchd.user.agents.<name>`

activation hook ではなく LaunchAgent として `~/Library/LaunchAgents/`
配下に plist を配置する経路。`RunAtLoad` で login 直後にコマンドを 1 回
発行する用途。

* `remap-caps-lock`: `system.keyboard.remapCapsLockToControl` の
  永続化補助。`hidutil property --set` は session-scoped で再起動時に
  揮発する (Apple TN2450) ため、login のたびに同 payload で再適用する。
  これがないと「新マシン bootstrap 後に再起動 → CapsLock が戻る」が
  起きてしまう。
