# 実装計画: dotfiles 移行 (Step A → B → mise → C の段階的 PR)

## Context

ユーザーの dotfiles を以下の動機で移行する:

1. **declarative な brew/cask 管理**: `homebrew.onActivation.cleanup = "uninstall"` で「宣言から外したら自動 uninstall」、git diff でパッケージ管理を表現、`darwin-rebuild --rollback` で世代単位のロールバック。`Brewfile + brew bundle` では得られない冪等性を獲得する。
2. **マシン別差分のテンプレート化**: username / email / `~/Documents/dev` 等のワークスペースパスを PC ごとに切り替えたい。chezmoi tmpl で表現する。
3. **言語ランタイム管理の近代化**: asdf を mise に置き換え。
4. **真の再現性 (オプション)**: CLI ツールバイナリも flake.lock で pin して別 Mac で同一バイナリを保証する。

実装は **4 つの独立した Step** に分け、各 Step ごとに branch を切り PR を出す。各 PR が main にマージされてから次の Step の branch を main から分岐する (stack 形式ではなく、各 Step が独立した PR)。

| 順 | Step | ブランチ | スコープ | 投資 | 動機との対応 |
|---|---|---|---|---|---|
| 1 | A | `migration/chezmoi` | homesick → chezmoi。テンプレート化 + シークレット注入 | 週末 1 回 | 動機 2 |
| 2 | B | `migration/nix-darwin-homebrew` | nix-darwin で brew/cask/macOS 設定を declarative 化 | 週末 1 回 | 動機 1 |
| 3 | mise | `migration/mise` | asdf → mise 移行 | 週末 1 回 (言語ビルドで超過の可能性) | 動機 3 |
| 4 | C | `migration/nix-native-cli` | brew で入れていた CLI ツールバイナリを Nixpkgs (Nix store) 由来に置き換える | 週末複数回 | 動機 4 |

各 Step 完了時点で環境は壊れていない状態を保つ。各 Step の前後で `legacy-homesick` ブランチをロールバック先として保持する。

## クリティカルファイル

### 既存 (移行元)

* `/Users/hideaki.ishii/.homesick/repos/dotfiles/home/Brewfile` (Step B で `nix/homebrew.nix` に変換)
* `/Users/hideaki.ishii/.homesick/repos/dotfiles/setup.sh` (Step B 完了で brew bundle 部分削除、Step mise で asdf 部分削除、Step C で残り全削除候補)
* `/Users/hideaki.ishii/.homesick/repos/dotfiles/_asdf.sh` (Step mise で削除)
* `/Users/hideaki.ishii/.homesick/repos/dotfiles/.homesick_subdir` (Step A 完了後に削除)
* `/Users/hideaki.ishii/.homesick/repos/dotfiles/home/.zshrc` (Step A でテンプレ化、Step mise で mise activate 追加、Step C で PATH 順序更新)
* `/Users/hideaki.ishii/.homesick/repos/dotfiles/home/.gitconfig` (Step A でテンプレ化)
* `/Users/hideaki.ishii/.homesick/repos/dotfiles/home/.codex/apply-config.sh` (Step A で envsubst 機構を chezmoi tmpl に統合)
* `/Users/hideaki.ishii/.homesick/repos/dotfiles/home/.apm/apm.yml` / `apm.lock.yaml` (Step A で drift 対策)

### 新規作成

* Step A: `.chezmoiroot`, `home/.chezmoi.toml.tmpl`, `home/.chezmoiignore`
* Step B: `flake.nix`, `flake.lock`, `nix/homebrew.nix`, `nix/system.nix`, `nix/hosts/<hostname>.nix`
* Step C: `nix/packages.nix`

---

## 全体準備

各 Step に着手する前に共通でやる作業:

* `legacy-homesick` ブランチを main から作成 (どこまで進んでも戻れる原点として保持)
* 必要に応じて Time Machine スナップショット
* 各 Step の作業ブランチは **main から切る** (前の Step がマージされた状態の main から)

---

## Step A: chezmoi 移行

### A-0. PR メタ情報

* ブランチ: `migration/chezmoi` (from main)
* PR タイトル: `feat(dotfiles): migrate from homesick to chezmoi`
* PR 概要: dotfile 管理を homesick から chezmoi に移行。username/email/workspace パスをテンプレ化し machineType (work/personal) で切り替え可能にする。1Password CLI 経由のシークレット注入を導入。Brewfile / asdf / Nix には触れない。

### A-1. 準備

* `brew install chezmoi` (Step B 完了後はこのインストールも `nix/homebrew.nix` 側で宣言する)
* リポジトリルートに `.chezmoiroot` を作成、内容は `home` (twpayne 公式 example と同じパターン)
* **pre-commit + secretlint** を導入: ルートに `.pre-commit-config.yaml`、`package.json` に `@secretlint/secretlint-rule-preset-recommend`、`prek install` を README に明記。1Password CLI 注入とは別レイヤで誤コミット防止。

### A-2. ファイルを chezmoi 命名規則にリネーム

| 現状 | chezmoi 名 |
|---|---|
| `home/.tmux.conf` | `home/dot_tmux.conf` |
| `home/.tmux.conf.d/` | `home/dot_tmux.conf.d/` |
| `home/.vimrc` | `home/dot_vimrc` |
| `home/.vim/` | `home/dot_vim/` |
| `home/.config/nvim/` | `home/dot_config/nvim/` |
| `home/.gitconfig` | `home/dot_gitconfig.tmpl` |
| `home/.zshrc` | `home/dot_zshrc.tmpl` |
| `home/.gitignore_global` | `home/dot_gitignore_global` |
| `home/.ctags.d/` | `home/dot_ctags.d/` |
| `home/.codex/` | `home/dot_codex/` (`config.toml.template` は `dot_codex/config.toml.tmpl` に統合) |
| `home/.codex/skills/` | mizchi 流に **`home/dot_codex/symlink_skills`** で `~/.claude/skills` を symlink (重複 source 統一)。skill ファイル本体は `dot_claude/skills/` 側のみで管理 |
| `home/.claude/` | `home/dot_claude/` (運用設計は A-4 参照) |
| `home/.apm/apm.yml` | `home/dot_apm/apm.yml` |
| `home/.apm/apm.lock.yaml` | `.chezmoiignore` で除外 (Git では追跡継続) |
| `home/Brewfile` | この時点では `home/Brewfile` のまま (Step B で移行) |

* `chmod` 系: `executable_*.sh` で実行権限、`private_*` でディレクトリ 700 / ファイル 600
* OS 別スクリプトは twpayne 流に **`home/.chezmoiscripts/darwin/`** に集約 (将来 Linux 対応する場合に差し替え容易)

### A-3. `.chezmoi.toml.tmpl` でマシン別データを定義

* **machineType の自動判定 + prompt fallback** (twpayne 公式 example の慣習):
  * 優先順 1: hostname に基づく自動判定 (`{{ if hasPrefix .chezmoi.hostname "work-" }}work{{ else if ... }}personal{{ end }}`)
  * 優先順 2: CI/devcontainer 検知 (`{{ if env "CODESPACES" }}ephemeral{{ end }}` 等で headless / ephemeral を自動分類)
  * 優先順 3: 自動判定不能のときのみ `promptStringOnce` で対話入力
  * **`promptString` ではなく `promptStringOnce`** を使う。二度目以降の `chezmoi init` で値を保持し、再入力を求められない
* `name` / `email` も `promptStringOnce`
* `chezmoi.homeDir`, `chezmoi.username`, `chezmoi.hostname` は組み込み変数で追加定義不要
* **`[edit] apply = true` の副作用に注意**: テンプレ syntax error を保存した瞬間 `~/.zshrc` が破壊されうる。本計画では採用するが、README に「テンプレを大きく変えるときは `chezmoi diff --watch` で先に検証する」運用ルールを明記する。
* `backupFileExtension = "backup"` を設定し、auto-rename された `*.backup` ファイルを「消す前に内容を確認」するルールを CLAUDE.md に追加 (chezmoi / home-manager 共通の罠)

### A-4. Claude Code 運用設計 (編集体験劣化対策)

`home/dot_claude/` 配下は直近の主要編集領域。`.chezmoiignore` で除外する範囲 (mizchi リポジトリの慣習に倣い、**各行に除外理由のコメント**を付ける):

```
# Claude Code が動的に書き換える領域 (drift 回避)
dot_claude/projects/**
dot_claude/todos/**
dot_claude/shell-snapshots/**
dot_claude/statsig/**
dot_claude/ide/**

# APM (apm install) が動的に更新するファイル
dot_apm/apm.lock.yaml

# age 鍵置き場 (defensive)
.config/age/**
```

* `dot_claude/hooks/*.sh` は `executable_` プレフィックスで実行権限付与
* `home/.claude/.gitignore` の APM 管理ファイルとの整合性を確認しながら設計
* **APM 連携**: mizchi リポジトリの `run_after_apm-install.sh` パターンを採用。`home/.chezmoiscripts/darwin/run_after_apm-install.sh` を作成し、`apm install --global --target claude` を chezmoi apply 後に実行。これで APM workflow が chezmoi に統合される

### A-5. テンプレート化の具体内容

`dot_gitconfig.tmpl`:
```
[user]
    name = {{ .name }}
    email = {{ .email }}
```

`dot_zshrc.tmpl`:
* workspace パスを `{{ .chezmoi.homeDir }}/Documents/dev` 等の形にする
* マシン別の環境変数 (例: `AWS_PROFILE`) は `{{ if eq .machineType "work" }} ... {{ end }}` で分岐

`dot_codex/config.toml.tmpl`:
* 既存の `${GEMINI_API_KEY}` 等を chezmoi の onepasswordRead 関数に置き換え (もしくは A 段階では env のままにして後段で 1Password 統合)

`private_dot_ssh/config.tmpl`:
* `Host` ブロックをマシン別に分岐

### A-6. シークレット管理 (1Password CLI + age の二経路併用)

mizchi リポジトリは age を採用、本計画ではユーザー要件に応じて 1Password CLI を主、age を fallback として併設する:

* **主**: 1Password CLI (`brew install --cask 1password-cli`、`op signin`)
  * テンプレート例: `{{ (onepasswordRead "op://Personal/GitHub/token") }}`
  * 制約: ネット必須、op CLI 認証必須 (オフラインで apply できない)
* **fallback**: age (`brew install age`、鍵を `~/.config/age/key.txt` に置く)
  * `encrypted_private_dot_envrc.age` のように `encrypted_` prefix で chezmoi に運ばせる
  * オフライン apply 可能、ただし鍵紛失で全ロスト → 1Password Vault に age 鍵をバックアップ
* どちらの経路でも apply できる構造にして、CI / devcontainer 等で 1Password が使えない状況を救済する

### A-7. 適用と動作確認

* `chezmoi init --apply --source ~/.homesick/repos/dotfiles/home`
* `chezmoi diff` でゼロ diff 確認
* `chezmoi verify` で乖離無し確認

### A-8. homesick からの切り替え

* `~/.homesick/repos/dotfiles/.homesick_subdir` を削除
* 既存の `~/` 配下の symlink (homesick が張ったもの) を削除
* `chezmoi apply` で実体を `~/` に展開
* リポジトリ root の `setup.sh` 内 `homesick link` 行はコメントアウトに留める (Step B/mise/C で順次削除)

### A-9. PR レビュー観点 / 完了条件

* `chezmoi diff` がゼロ
* `git config --get user.email` が machineType に応じて正しい値
* `cd $WORKSPACE` 系のコマンドが正しいパスを指す
* `claude --version` 起動、`claude mcp list` が正常
* `apm install` が正常動作 (`run_after_apm-install.sh` 経由でも手動でも)
* `op read op://...` がテンプレートから取得できる
* age 経路でも復号できる (1Password 経路と二系統で動作確認)
* tmux/vim プラグインのロードが従来通り
* `home/.claude/projects/` 等の動的書き換えで `chezmoi verify` が壊れない (drift 対策確認)
* hostname を変えて `chezmoi init` し直したら machineType の自動判定が動く (work / personal の hostname プレフィックス確認)
* `chezmoi init` を二度目以降走らせても `promptStringOnce` が値を保持して再質問しない
* `pre-commit` hook で `secretlint` が動作 (試しに API key っぽい文字列をコミットしようとして blocked になることを確認)

---

## Step B: nix-darwin で brew/cask/macOS 設定を declarative 化

### B-0. PR メタ情報

* ブランチ: `migration/nix-darwin-homebrew` (from main, Step A マージ後)
* PR タイトル: `feat(dotfiles): introduce nix-darwin to manage brew/cask declaratively`
* PR 概要: nix-darwin を導入し、Brewfile を `nix/homebrew.nix` に declarative 化。macOS システム設定 (Dock/Finder/KeyRepeat) も `nix/system.nix` で宣言。CLI バイナリは引き続き Homebrew 供給 (Nix native 化は Step C)。

### B-1. Nix インストール

* **公式 Nix インストーラを使用** (Determinate Installer は 2026/01〜 upstream Nix 不可):
  ```
  sh <(curl -L https://nixos.org/nix/installer)
  ```
* Flakes 有効化:
  ```
  mkdir -p ~/.config/nix
  echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
  ```
* 動作確認: `nix run nixpkgs#hello`

### B-2. flake.nix 作成

inputs: `nixpkgs` (release-25.11), `nix-darwin`, `nix-homebrew`。`darwinConfigurations.<hostname>` を `nix/hosts/<hostname>.nix` から組み立てる。

### B-3. nix/homebrew.nix 作成 (Brewfile の declarative 化)

* `taps`: `["adoptopenjdk", "homebrew/cask-fonts", "daipeihust/tap", "microsoft/apm"]`
* `brews`: 現 76 個 (`microsoft/apm/apm` 含む) + `chezmoi` 追加
* `casks`: 現 30 個
* `onActivation.cleanup = "check"` で初回開始 (予期せぬ uninstall 回避)
* 動作が安定したら `"uninstall"` に切り替え

### B-4. nix/system.nix 作成 (macOS システム設定)

範囲を OS 全体設定に限定:
* `system.defaults.dock.*`
* `system.defaults.finder.*`
* `system.defaults.NSGlobalDomain.InitialKeyRepeat` / `KeyRepeat`
* `system.defaults.trackpad.*`

アプリ単位の設定 (1Password, Raycast, Karabiner 等) は範囲外。必要なら chezmoi 側で `run_once_*.sh` を流す。

### B-4.5. brew と Nix の住み分け強化

mizchi リポジトリの慣習を採用:

* `environment.variables.HOMEBREW_FORBIDDEN_FORMULAE = "node python python3 pip npm pnpm yarn claude"` を設定。brew が language runtime を勝手に入れないよう環境変数レベルで禁止 → mise / Nix と棲み分け。Step C で Nix 側にランタイムを引き取った時の事故予防にもなる
* `nix.enable` / `programs.zsh.enable` の設定: Determinate / nix-darwin が `/etc/zshrc` を上書きして `chezmoi` 側の zshrc と競合する事故を防ぐ。`programs.zsh.enable = false` で nix-darwin に zsh 設定を触らせない (zshrc 管理は chezmoi 側に集約)
* `/etc/zshrc.backup` などの auto-rename ファイルが残ったら内容確認してから削除する運用ルールを README に明記

### B-5. nix/hosts/<hostname>.nix 作成

host 毎に `nix/homebrew.nix` と `nix/system.nix` を import。マシン別の追加 cask/brew があればここで宣言。

### B-6. 適用

* `nix run nix-darwin -- switch --flake .#<hostname>`
* `cleanup = "check"` の状態で「未管理」リストを精査 → すべて宣言済みを確認
* 確認後 `cleanup = "uninstall"` に切り替えて再適用

### B-7. 旧 Brewfile と setup.sh の整理

* `home/Brewfile` を削除
* `setup.sh` から brew bundle / brew install 部分を削除 (Xcode/Rosetta 部分は残す)

### B-8. flake.lock 運用方針 (README に追記)

* 部分更新を基本に:
  ```
  nix flake lock --update-input nixpkgs
  nix flake lock --update-input nix-darwin
  ```
* 全更新 `nix flake update` は壊れた時の切り分け困難なので避ける
* 壊れた時のロールバック:
  ```
  darwin-rebuild --list-generations
  darwin-rebuild --rollback
  ```

### B-9. PR レビュー観点 / 完了条件

* `darwin-rebuild check --flake .#<hostname>` がエラー無し
* `which git`, `which node`, `which python` が brew 配下のパスを指す (Nix native 化していないため)
* `brew list` の内容が `nix/homebrew.nix` 宣言と一致 (`cleanup = "uninstall"` 後)
* macOS 設定 (Dock の挙動、KeyRepeat) が反映
* `apm install` 等が引き続き動作
* 意図的に `nix/homebrew.nix` から 1 つ brew を削除 → `darwin-rebuild switch` → 自動 uninstall を確認 → `--rollback` で復活を確認
* APM、Claude Code、Codex が引き続き動作

---

## Step mise: asdf → mise 移行

### mise-0. PR メタ情報

* ブランチ: `migration/mise` (from main, Step B マージ後)
* PR タイトル: `feat(dotfiles): migrate language version manager from asdf to mise`
* PR 概要: 言語ランタイム管理を asdf から mise に移行。mise バイナリは `nix/homebrew.nix` で宣言 (Step C で Nixpkgs 経由に切り替え可能)。Nix native 化は範囲外。

### mise-1. mise 導入と並走期間の設定

* `nix/homebrew.nix` の `brews` に `mise` を追加 → `darwin-rebuild switch` で導入
* `dot_zshrc.tmpl` に `eval "$(mise activate zsh)"` を追加 (asdf init より **後**、PATH 上で mise が優先されるよう配置)
* `chezmoi apply` で反映

### mise-2. 既存 .tool-versions の再 install

* `mise install` で `~/.tool-versions` の全言語を再 install
* **失敗が起きやすい領域**:
  * Python の openssl 依存問題 → `mise use python@3.12` で precompiled binary 利用
  * Ruby のビルド依存 (libyaml, openssl, readline) → `mise use ruby@3.x --pin` + 必要なら `MISE_RUBY_BUILD_OPTS` 設定
  * Node.js は概ね問題なし
  * Go, Rust, Deno, Terraform, kubectl, AWS CLI は precompiled binary が基本
* 各プロジェクトで動作確認 (asdf と並走中、mise が PATH 上で勝つ状態)

### mise-3. asdf アンインストール

* 全言語が mise 経由で動くことを確認したら:
  * `dot_zshrc.tmpl` から asdf init 行を削除
  * `nix/homebrew.nix` から `asdf` を削除 → `darwin-rebuild switch` で自動 uninstall
  * `~/.asdf/` を `rm -rf` で削除 (要確認)
* `_asdf.sh` をリポジトリから削除
* `setup.sh` から asdf 関連行を削除

### mise-4. README / CLAUDE.md 更新

* セットアップ手順から asdf 記述を削除し mise 記述に
* `_asdf.sh` の言及を削除

### mise-5. PR レビュー観点 / 完了条件

* 既存プロジェクトすべてで `mise install` 成功 (or precompiled binary で代替)
* `which node`, `which python`, `which ruby`, `which go` が mise shim 配下を指す
* asdf アンインストール後にプロジェクトが動く
* 別プロジェクトで `mise use` を新規追加して動作することを確認
* `setup.sh` と CLAUDE.md が新運用を反映

---

## Step C: CLI ツールを Nix native 化 (オプション)

### C-0. 動機の再確認

Step C は「**真の再現性 (flake.lock pin)**」と「**世代管理が CLI バージョン本体まで及ぶ**」が動機。Step B + mise 完了時点で動機が満たされていれば見送ってよい。

### C-1. PR メタ情報

* ブランチ: `migration/nix-native-cli` (from main, mise マージ後)
* PR タイトル: `feat(dotfiles): move CLI tools from Homebrew to Nix store`
* PR 概要: brew で入れていた CLI ツールバイナリ (git, tmux, neovim, fzf, ripgrep, jq, yq, direnv, gh 等) を Nixpkgs (`environment.systemPackages`) 経由に置き換え、`flake.lock` で nixpkgs commit に pin する。

### C-2. nix/packages.nix 作成

* `environment.systemPackages = with pkgs; [ git tmux neovim fzf ripgrep jq yq direnv gh ... ]`
* 移行対象は `nix/homebrew.nix` の `brews` のうち Nixpkgs に存在するもの
* **APM (`microsoft/apm/apm`) は community flake [`numtide/llm-agents.nix`](https://github.com/numtide/llm-agents.nix) で packaging 済み**。`flake.nix` の inputs に追加して `inputs.llm-agents.packages.${system}.apm` を `environment.systemPackages` に含めれば Nix 完結可能 (numtide が daily auto-update)
* それでも残置するもの: cask アプリ (VSCode, Cursor, 1Password 等)、Nixpkgs / community flake いずれにも無いツール

### C-3. PATH 順序の調整

* `dot_zshrc.tmpl` で Nix store (`/run/current-system/sw/bin`) が `/opt/homebrew/bin` より **前** に来るよう調整
* mise activate より前に PATH を整える

### C-4. 重複の解消

* `nix/homebrew.nix` の `brews` から Nixpkgs に移行した分を削除
* `darwin-rebuild switch` で `cleanup = "uninstall"` が brew 側を自動で消す
* `which <cmd>` が Nix store 配下を指すことを確認

### C-5. flake.lock 運用 (Step B-8 の方針を踏襲)

* 部分更新を基本に
* 壊れた時は `darwin-rebuild --rollback`

### C-6. PR レビュー観点 / 完了条件

* `which git`, `which tmux`, `which neovim` が Nix store 配下を指す
* `git --version` 等のバージョンが `flake.lock` の nixpkgs commit から導かれる値と一致
* `brew list` から CLI が消え、cask と microsoft/apm/apm 系のみが残る
* `darwin-rebuild --rollback` で前世代に戻り、Nix 由来 CLI のバージョンが戻ることを確認
* mise との PATH 競合がない (mise shim が言語ランタイムを優先供給する)
* APM、Claude Code、Codex、すべてのプロジェクトが引き続き動作

---

## ロールバック手順 (各 Step ごと)

| Step | 適用前 | 適用後の問題発覚時 |
|---|---|---|
| A | `git checkout main` | `legacy-homesick` ブランチ → `homesick link dotfiles` で symlink 再構築 |
| B | `git checkout main` | `darwin-rebuild --rollback`、それでも壊れていれば `flake.lock` を git で前状態に巻き戻し → 再 `darwin-rebuild switch` |
| mise | `git checkout main` | mise を `brew uninstall mise` (Step B 後なので nix-darwin 経由で削除可)、asdf 復帰 |
| C | `git checkout main` | `darwin-rebuild --rollback`、PR を revert して `nix/homebrew.nix` に CLI を戻す |

最悪のケース (Nix 自体が壊れた場合): `/nix/uninstall.sh` または `/nix/receipt.json` の手順で Nix をアンインストール → `legacy-homesick` ブランチに戻る。

---

## 統合検証 (全 Step 完了後)

別マシン (or テスト用 git checkout path) で以下のセットアップフローが完走することを確認:

1. 公式 Nix インストーラ実行
2. Flakes 有効化
3. リポジトリ clone
4. `nix run nix-darwin -- switch --flake .#<hostname>`
5. `chezmoi init --apply --source ~/dotfiles/home` (machineType / name / email を答える)
6. `op signin` で 1Password CLI セットアップ
7. `mise install` で言語ランタイム導入
8. zsh / vim / nvim / tmux / git / claude / codex / apm がすべて動作

---

## 補足: 各 Step のスコープ境界 (混乱しやすいので明示)

### Step B と Step C の違い

* **Step B = 宣言の場所だけ変える** (バイナリは引き続き Homebrew が供給)
* **Step C = バイナリの供給元自体を変える** (Homebrew → Nixpkgs / Nix store)

| 観点 | Step B | Step C |
|---|---|---|
| `git` の入手元 | Homebrew (`/opt/homebrew/Cellar/git/...`) | Nixpkgs (`/nix/store/<hash>-git/bin/git`) |
| `which git` | `/opt/homebrew/bin/git` | `/run/current-system/sw/bin/git` |
| バージョン pin | Homebrew formula 最新 (弱) | `flake.lock` の nixpkgs commit (強) |
| 別 Mac で同一バイナリ保証 | なし | あり |
| 自動 uninstall | `cleanup = "uninstall"` | `darwin-rebuild switch` |
| 学習コスト | flake / nix-darwin の最低限 | + Nixpkgs 探索 / overlay / derivation / ビルド失敗デバッグ |
| nixpkgs 追従ラグの影響 | 小 | 大 |

declarative 化と自動 uninstall は **Step B 時点で既に得られる**。Step C で追加で得られるのは「真の再現性」と「世代管理が CLI 本体に及ぶ」のみ。

### Step C と Step mise の独立性

Step C (Nix native 化) と Step mise (asdf → mise) は元計画書では一括だったが、実際は独立して進められる。本計画では mise を先行 (Step B 後すぐ) に配置。

* mise バイナリは Step mise 段階では brew 経由 (`nix/homebrew.nix` で宣言)、Step C で Nixpkgs 経由に切り替え可能
* 言語ランタイム (Node/Python/Ruby) は mise 管理下で、Nix も Homebrew も触らない領域

### 採用しない選択肢 (home-manager 統合)

zshrc 等を Nix DSL で書く home-manager は本計画では対象外。理由:
* 既存の育った zshrc/vimrc を Nix DSL に書き直す移行コストが大きい
* ユーザーの明示要件 (テンプレート化 + シークレット注入) は chezmoi の方が直接的
* 「dotfile は chezmoi、パッケージは Nix」の責任分界点を維持する方が認知負荷が低い

---

## 参考: 外部ベンチマーク (mizchi/chezmoi-dotfiles + twpayne 公式)

### mizchi/chezmoi-dotfiles から採り入れた要素

* `run_after_apm-install.sh` パターン → A-4 で採用 (APM workflow を chezmoi に統合)
* `symlink_skills` で重複 source を symlink 化 → A-2 で採用 (`dot_codex/symlink_skills` で `dot_claude/skills` を共有)
* `.chezmoiignore` の各行コメント → A-4 で採用 (除外理由を可読に)
* `encrypted_` (age) と CLI の二経路シークレット → A-6 で採用 (1Password 主、age 副)
* `HOMEBREW_FORBIDDEN_FORMULAE` で language runtime 二重管理回避 → B-4.5 で採用
* `nix-darwin` と `programs.zsh.enable = false` で `/etc/zshrc` 競合回避 → B-4.5 で採用
* pre-commit + secretlint で誤コミット防止 → A-1 で採用

### twpayne 公式 example から採り入れた要素

* `.chezmoiroot = "home"` → 元計画書のまま採用 (一致)
* hostname ベースで machineType 自動判定 + `promptStringOnce` fallback → A-3 で採用
* CI / devcontainer 検知 (`env "CODESPACES"`) で ephemeral 自動分類 → A-3 で採用
* `.chezmoiscripts/{darwin,linux}/` で OS 別スクリプト分離 → A-2 / A-4 で採用 (将来 Linux 対応の差し替え容易性)

### 採用しなかった要素と理由

* mizchi の **`.chezmoiroot` 不採用 (トップレベル直置き)**: 本計画は `.chezmoiroot = "home"` を維持。ユーザーの既存 dotfiles が `home/` 配下に集約されているため、移行コストが小さい
* mizchi の **`.chezmoi.toml.tmpl` 不採用 (Nix flake 側 private.nix で値を保持)**: 本計画は chezmoi の `promptStringOnce` を採用。Step A 段階では Nix がまだ無いため、chezmoi 単体で完結する方が段階移行に整合
* mizchi の **macOS / Apple Silicon 固定**: 本計画も同方針 (Linux 対応は当面見送り、ただし `.chezmoiscripts/darwin/` 構造で将来の余地を残す)

## 参考: レビュー要点 (本実装計画策定の根拠)

* 計画書原案の前提のうち `Brewfile 100+`, マシン別差分なしは現状と一致
* `setup.sh` の保守コスト自体は低い (78 行、年数回しか触らない) → 移行の主動機は declarative + テンプレ化 + 言語管理の近代化
* APM (`microsoft/apm/apm`) は公式 Nixpkgs には無いが community flake `numtide/llm-agents.nix` で packaging 済み (Step C で Nix 完結化のオプションあり、Step A + B では brew のまま)
* `home/.claude/` の編集頻度が高いため chezmoi 化の編集体験劣化リスクあり (A-4 で対策)
* `apm.lock.yaml` 等「アプリが書き換えるファイル」の drift 対策必要 (`.chezmoiignore` で除外、A-4)
* Determinate Installer は 2026/01 から upstream Nix 不可 (B-1 で公式 installer 採用)
* nix-darwin の Homebrew モジュールは初回 `cleanup = "check"` 推奨 (B-3 で採用)
* mise は `.tool-versions` 完全互換ではなく、既存 `~/.asdf/installs` は再ビルド必須 (mise-2 で対処)
