# アーキテクチャリファレンス

[English](architecture.md) | 日本語

このリポジトリの「何がどこにあって、内部でどう繋がっているか」を引くための
リファレンス。設計思想 (なぜ declarative / 配置パターンの選択基準) は
[docs/design-philosophy-ja.md](design-philosophy-ja.md) 参照。

ディレクトリ構造の完全ツリーは
[design-philosophy-ja.md#ディレクトリ構造](design-philosophy-ja.md#ディレクトリ構造)
にある。本 doc は per-tool の内部構成を主に扱う。

## レイヤー責務 (要点)

* `flake.nix` — `darwinConfigurations.<host>` を `mkHost` で宣言。`hosts`
  attrset の各 entry に `user` (macOS account) / `gitName` / `gitEmail` を
  持ち、`mkHost` で `dotfilesPath = "/Users/${user}/Documents/dev/dotfiles"`
  を派生させて `specialArgs` 経由で全モジュールに流す (各 .nix で重複定義しない)。
  `hostname` は system と home-manager の両方へ渡し、Grok Build の personal 限定判定に使う
* `nix/darwin/` — nix-darwin (system 層)。`default.nix` が配下を一括 imports。
  flake.nix からは `./nix/darwin` 1 つを import するだけ
* `nix/home/` — home-manager (user 層)。`default.nix` が entry point、
  `programs/<tool>.nix` で 1 ファイル 1 ツール
* `tools/<tool>/` — `home.file` で symlink される raw text dotfile の置き場
* `setup.sh` — 初回 bootstrap (Xcode CLT → Nix → CA bundle → flake host 検証 →
  /etc 退避 → darwin-rebuild → mise install → LSP global → prek)

各モジュールが何を担当するか (system 層 6 ファイルの内訳 / home 層の
責務分担) は [README-ja.md#管理ツールの責務分担](../README-ja.md#管理ツールの責務分担)
を参照。

## `~/` 配置先

`home.file` 経由で home-manager が配置するもの:

* `.zshrc` `.tmux.conf` `.tmux_start_dir` `.markdownlint.jsonc` `.ctags.d/`
* `.config/{git,google-ime,herdr,mise,nvim}/` (XDG)
* `.claude/` (CLAUDE.md / settings.json / hooks/ / rules/ /
  mcp-servers.json / skills/.gitignore + 動的領域 projects/ todos/
  shell-snapshots/ statsig/ ide/)
* `.codex/` (config.toml は pkgs.formats.toml 生成物を activation で mutable
  コピー / AGENTS.md → tools/codex/AGENTS.md (→ tools/claude/CLAUDE.md) symlink
  * 動的領域 sessions/ log.json。apm skill は ~/.agents/skills/ 側に入る)
* `.grok/managed_config.toml` (Claude 互換 hooks を無効化する静的設定)。
  `~/.grok/config.toml`、認証、セッション、ダウンロードは Grok Build が管理する
  mutable 領域として home.file の対象外にする
* `.apm/` (apm.yml / apm.lock.yaml / .gitignore + 動的領域 apm_modules/
  config.json / .claude/ / .github/)
* `.local/bin/tmux-start` (executable)
* `Library/Application Support/com.mitchellh.ghostty/config`
* `Library/Application Support/Code/User/{settings,keybindings}.json`

動的領域 (ツールが自走で書き換える dir) は home.file 対象外として ~/ 配下
の mutable directory として残す。詳細は
[design-philosophy-ja.md#動的領域の扱い](design-philosophy-ja.md#動的領域の扱い)。

## Neovim

* Plugin manager: lazy.nvim (`~/.local/share/nvim/lazy/` は home.file
  対象外、lazy.nvim 自走で書き換える領域)
* LSP / 補完: nvim-lspconfig (新 API `vim.lsp.config` + `vim.lsp.enable`)
  * nvim-cmp。Ruby は `Gemfile.lock` に `gem "ruby-lsp"` が含まれるかで
  `ruby_lsp` / `solargraph` を排他的に切替
  (`tools/nvim/lua/plugins/lsp.lua`)。各 server に `cmd` を明示して
  PATH 上に binary が無い場合は enable を skip
  * LSP server は Nix 配布と `setup.sh` による mise runtime 配下の global
    install を併用する。Neovim は PATH にある server だけを enable するため、
    未導入 server は spawn されない
* Tree-sitter: nvim-treesitter (main branch、
  `tools/nvim/lua/plugins/treesitter.lua`)
* 配置: `nix/home/programs/nvim.nix` が `tools/nvim/` 全体を `~/.config/nvim`
  に 1 行で out-of-store symlink (plugin 実体は `~/.local/share/nvim/lazy/`
  に書かれるので repo は触られない)。`tools/nvim/lazy-lock.json` は tracked
  にして再現性を担保
* 構成: `tools/nvim/init.lua` から `lua/options.lua` `lua/mappings.lua`
  `lua/autocmds.lua` をロード、
  `lua/plugins/{editor,ui,cmp,lsp,format,treesitter,lang}.lua`
  が lazy.nvim spec、`after/ftplugin/<lang>.lua` が言語別 local 設定
* 社内 VPN の SSL inspection 対策: `tools/nvim/init.lua` 冒頭で
  `/etc/nix/ca-bundle.pem` を `GIT_SSL_CAINFO` / `CURL_CA_BUNDLE` /
  `SSL_CERT_FILE` に注入 (lazy.nvim の git clone と nvim-treesitter の
  curl parser ダウンロードを通すため)。deno LSP は `DENO_CERT` を別途要求

## Shell Environment

* Shell: Zsh + starship prompt (`programs.starship.settings` で declarative 管理)
* mise の zsh integration は無効化 (`enableZshIntegration = false`)、
  `tools/zsh/.zshrc` に `eval "$(mise activate zsh)"` を手書き 1 行
  (starship も同様)。これは zshrc を repo の raw text として symlink 配置
  している都合上、home-manager に zshrc 注入を許すと衝突するため

## Claude Code

* `claude` 本体は公式 native installer で `~/.local/bin/claude` に入れる。
  これは mutable latest tool として扱い、`flake.lock` や darwin generation の
  rollback 対象にはしない
* `tools/claude/skills/.gitignore` のみ tracked、APM が install する skill
  (chrome-cdp, codebase-analyzer, ...) は `~/.claude/skills/` 配下に展開され
  gitignore で ignore される (codex にも同一 skill が cross-agent 標準の
  `~/.agents/skills/` に配布される。下記 Codex 参照)
* MCP server 設定は codex と共有する `tools/mcp/servers.json` を single source
  of truth とし、`tools/claude/setup-mcp.sh` を `cd tools/claude &&
  ./setup-mcp.sh` で実行して `claude mcp add` 経由で user-scope の mutable
  config に登録する (apply 時には自動実行されない)
* `rules/*.md` (`~/.claude/rules/` は claude が `@import` 不要で自動ロードする
  user-level rule) に markdown / nix / web-fetch / tools の指針を置く。`nix.md` は
  `paths:` frontmatter で `**/*.nix` にスコープする
* `hooks/` に PreToolUse の破壊コマンド遮断 (block-destructive-commands.py) と
  PR 作成ゲート (pr-review-gate.sh: `/code-review` 未実行なら `gh pr create` を
  exit 2 でブロック / pr-review-mark.sh が PostToolUse(Skill) で marker 設置)、
  PostToolUse の markdownlint 自動修正を配置
* `settings.json` は raw symlink で live-edit 可能。`$schema` (schemastore) を
  持ち、`claudeSettingsValidate` activation hook が switch 時に check-jsonschema で
  非ブロッキング検証する (壊れた設定の早期検知。live-edit は維持)

APM の install hook / skill 取り込み手順は
[README-ja.md#claude-code-skills-via-apm](../README-ja.md#claude-code-skills-via-apm)
参照。

## Grok Build

* `nix/home/programs/grok.nix` は `hostname == "personal"` のときだけ有効。
  xAI 公式 installer を activation hook から初回だけ実行し、
  `~/.grok/bin/grok` を canonical path、`~/.local/bin/grok` を PATH 用 symlink とする
* `~/.grok/config.toml` は installer と Grok が更新するため管理対象にしない。
  `~/.grok/managed_config.toml` だけを home-manager の静的 text として配置し、
  Claude Code hooks を `compat.claude.hooks = false` で無効化する
* Grok の Claude 互換機能を通じて `~/.claude/CLAUDE.md`、rules、skills、agents、
  MCP を再利用する。Codex の config、profile、custom agent、hooks は形式が異なるため
  直接コピーしない

## Codex

* `codex` 本体は公式 native installer で `~/.local/bin/codex` に入れる。
  Claude Code と同じく mutable latest tool として扱い、`flake.lock` や
  darwin generation の rollback 対象にはしない
* `~/.codex/config.toml` は `settings` (Nix attribute set) を
  `pkgs.formats.toml` で生成し、`codexConfig` activation hook が mutable な
  実ファイルとして毎回上書き配置する。codex 自身が起動時に `[projects]`
  trust を config.toml へ追記するため read-only symlink にはできない
  (書込が code -32603 で失敗する)。設定の編集後は `nix run .#switch` 必須
* モデル運用は実装を Luna、設計・方針策定とレビューを Sol、難しい end-to-end の
  統合を Astra に分ける。デフォルトは `gpt-5.6-luna` / max で、root の実装は
  max を維持する。custom agent は `worker` が Luna / max、`explorer` が Luna /
  medium、`verifier` と `architect` が Sol / high、未指定の subagent は Luna /
  high とする。built-in の `/review` も Sol を使う
  不確実性や失敗コストが高い複数段階の作業は `codex -p astra`
  (`gpt-6-astra` / high) を使い、最難関だけ `-c model_reasoning_effort=max` へ
  明示的に昇格する。Astra profile は base の承認、sandbox、MCP、hooks、agent 設定を
  継承し、実働を Luna の worker / explorer と Sol の verifier にまとまった単位で
  渡す。委譲時は自己完結した指示を渡し、不要な会話履歴の引き継ぎや重複調査を避ける
* Luna で設計判断が必要になったら custom agent `architect`
  (gpt-5.6-sol / high / read-only) に相談し、タスク全体が設計検討なら
  `codex -p sol` (advisor モード) を使う。Astra は設計を担当し、未解決の論点だけ
  Sol に相談する。複数ファイルにまたがる振る舞い、高リスク、実行時設定・データ・
  互換性の変更は、実装後に `verifier` agent が成功条件ごとの証拠と
  `PASS / FAIL / INCONCLUSIVE` を返すまで完了扱いにしない。文書・コメントだけの
  変更や自明な機械的変更は直接検証でよい。委譲には明示的な user / project / skill
  指示が必要で、利用できない場合は root が必要な検証を直接行う
* `~/.codex/sol.config.toml` は advisor モード用の profile (model = sol /
  read-only sandbox)。現行 codex の profile v2 は config.toml 内の
  `[profiles.<name>]` (legacy) を拒否し `<name>.config.toml` の別ファイルを
  要求する。codex は profile ファイルにも trust 等の状態を追記するため、
  config.toml と同じく `codexConfig` hook が mutable 実ファイルとして毎回
  上書きする
* `~/.codex/astra.config.toml` は難しい end-to-end 作業用の profile
  (`model = gpt-6-astra` / `high`)。`codex -p astra` で起動し、最難関だけ
  `-c model_reasoning_effort=max` を追加する。worker / explorer は Luna のまま、
  verifier は Sol とし、Astra root の推論を設計・方針策定・統合へ集中させる
* `~/.codex/agents/` は `tools/codex/agents/` への out-of-store symlink。
  worker (luna / max)、explorer (luna / medium)、verifier / architect (sol /
  high) の custom agent を管理する。subagent の同時実行上限は 8
* base config は `approval_policy=on-request` と `sandbox_mode=workspace-write`。
  repo 内の操作は進め、sandbox 外だけ承認を求める。herdr の launcher は CLI で
  `--ask-for-approval never` と `--sandbox workspace-write` を明示するため、
  自動運転の例外として別に扱う。環境変数は `inherit=all` を維持しつつ、Codex
  の secret-like な既定除外を有効にして subagent への漏えい範囲を抑える
* Fast mode は既定有効にしない。速度向上はクレジット消費を増やすため、必要な
  セッションだけ `/fast on` を使い、`/fast status` で確認する
* `tools/codex/scripts/codex-usage-report.py` は rollout jsonl からモデル別
  トークンと委譲状況を集計する (Sol の消費が設計相談に限定されているかの
  検証用。`--days` で期間指定)
* MCP server は claude と共有する `tools/mcp/servers.json` を `codex.nix` が
  `builtins.fromJSON` で読み `mcp_servers` に展開する (single source of truth)。
  現状は `context7` / `terraform` のみ
* skill は `apm.nix` の `apm install --target claude,codex --global` で
  cross-agent 標準の `~/.agents/skills/` に配布され、codex がそこを
  auto-discover する (`~/.codex/skills/` は codex 内蔵の `.system` 専用)。
  社内 MDM が Claude Code 用に配布した GWS Skill は、`codexGwsSkills`
  activation hook が同じ場所へ個別 symlink して再利用する。配布元が無い
  環境では何もしない
* `~/.codex/AGENTS.md` は `tools/codex/AGENTS.md` への out-of-store symlink。
  `tools/codex/AGENTS.md` 自体が `../claude/CLAUDE.md` への in-repo symlink な
  ので、claude と同じ system instruction を 1 ファイルで共有する
* `~/.codex/hooks.json` / `~/.codex/hooks/` は `tools/codex/` への
  out-of-store symlink。`PreToolUse` hook が破壊的な Bash command を Claude Code
  と同じポリシーで遮断する。hook は sandbox / approval policy の補助であり、
  変更後は `/hooks` で内容を再確認して trust する
  (`unified_exec` の interception は現状不完全なため、hook 単独で強制しない)
* `~/.codex/rules/destructive.rules` は管理対象の Codex exec policy への
  out-of-store symlink。`git reset --hard` のように危険性が固定 prefix で
  確定する操作は `forbidden`、`git push` のような広い変更操作は承認必須にする。
  exec policy は sandbox 外実行の可否を制御する。Codex が `default.rules` を
  更新できるよう、親の `~/.codex/rules/` は mutable のままにする
* turn 完了通知は `Stop` の非同期 hook (`tools/codex/hooks/notify.py`) を使い、
  承認待ち通知は terminal が unfocused のときの `tui.notifications` を使う。
  top-level `notify` はセッション復元時に過去の完了を再通知し得るため使わない。
  Claude の markdown 自動修正と PR 作成前レビューゲートは、Codex に同等の
  信頼できる hook 入力・イベントがないため移植しない

secrets 注入経路全体の設計は
[design-philosophy-ja.md#secrets-設計](design-philosophy-ja.md#secrets-設計)
と [README-ja.md#シークレット注入](../README-ja.md#シークレット注入) 参照。

## herdr

AI coding agent 向けの terminal workspace manager。tmux の代替ではなく併用で、
tmux prefix は `C-t`、herdr prefix は default の `ctrl+b` なので衝突しない。

* binary は nixpkgs 未収載のため Homebrew 供給 (`nix/darwin/homebrew.nix`)。
  更新は `brew upgrade herdr` の後に `herdr server stop` (常駐 server の項参照)。
  herdr は Homebrew 管理下の binary を検出すると self-update を拒否して brew へ
  誘導するので、経路は 1 本に保たれる
* server は `nix/darwin/herdr.nix` の `launchd.user.agents.herdr-server`
  (KeepAlive + RunAtLoad) で login 時常駐。boot 直後に server が居らず初回
  `herdr-start` が `detached from server` を出す race への対処。formula の
  `service do / keep_alive true` を declarative agent へ写したもので、
  `brew services start herdr` は併用禁止 (socket を奪い合う)。初回だけ既存の
  ad-hoc server を `herdr server stop` で止めてから switch する手動 bootstrap が
  要る (詳細は README-ja.md#herdr-server-の常駐-launchagent)
* `~/.config/herdr/config.toml` は `tools/herdr/config.toml` への out-of-store
  symlink (配置パターン A)。`herdr server reload-config` / prefix+shift+r で
  live reload されるので switch を挟まない
* config.toml は herdr 自身が書き換えうる (onboarding の選択 /
  `herdr channel set` / `herdr config reset-keys`)。symlink 先が repo の実
  ファイルなので書込は repo に届く。config 冒頭の `onboarding = false` で自動
  発火する経路だけは塞ぎ、残りは「叩かない」で運用する
* CJK IME 対策として `[experimental]` の
  `switch_ascii_input_source_in_prefix` (prefix mode 中だけ ASCII 配列へ退避) と
  `reveal_hidden_cursor_for_cjk_ime` + `cjk_ime_agents` (Claude Code / codex の
  TUI で変換候補ウィンドウを追従させる) を有効化している。後者の allow-list を
  agent に絞るのは、全 pane が対象だと vim の normal mode 等で cursor が二重に
  見えるため
* agent-state 連携の hook は `herdr integration install claude` / `... codex` を
  1 度だけ手で実行して生成し、成果物を commit する。activation hook にしないのは
  生成物が tracked file で、commit 済みなら他マシンには symlink でそのまま渡る
  ため (setup-mcp.sh / Google IME keymap と同じ手動 bootstrap)
* 生成物の着地先は claude と codex で非対称。claude は `~/.claude/hooks` が
  ディレクトリ symlink なので `tools/claude/hooks/` へ自動的に落ちるが、
  `~/.codex` は mutable な実ディレクトリなので `codex.nix` が
  `.codex/herdr-agent-state.sh` の symlink を明示的に宣言して tracked にする

## VSCode

`tools/vscode/` 配下の raw config を `nix/home/programs/vscode.nix` が
home-manager 経由で配置する。

* `settings.json` は `builtins.readFile + replaceStrings` で `${HOME}` を
  解決して `text =` で in-store 生成 (jsonc コメント保持)
* `keybindings.json` は out-of-store symlink (直接編集 → reload で即反映)
* extensions は `home.activation.vscodeExtensions` hook が `extensions.txt`
  と `code --list-extensions` の差分のみ install (冪等)

詳細運用 (sync.sh / UI 編集の取り込み / SSL inspection 対応) は
[docs/vscode-use-ja.md](vscode-use-ja.md) 参照。
