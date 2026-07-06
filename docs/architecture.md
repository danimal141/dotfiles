# Architecture Reference

English | [日本語](architecture-ja.md)

A reference for looking up "what lives where and how it wires together" in
this repository. For the design rationale (why declarative / how to pick a
placement pattern), see
[docs/design-philosophy.md](design-philosophy.md).

The full directory tree lives in
[design-philosophy.md#directory-layout](design-philosophy.md#directory-layout).
This doc focuses mostly on per-tool internals.

## Layer responsibilities (overview)

* `flake.nix` — declares `darwinConfigurations.<host>` via `mkHost`. Each
  entry in the `hosts` attrset carries `user` (macOS account) / `gitName` /
  `gitEmail`, and `mkHost` derives
  `dotfilesPath = "/Users/${user}/Documents/dev/dotfiles"` and threads it
  through `specialArgs` to every module (no per-module duplication).
* `nix/darwin/` — nix-darwin (system layer). `default.nix` imports the
  whole directory; `flake.nix` only needs to import `./nix/darwin` once.
* `nix/home/` — home-manager (user layer). `default.nix` is the entry
  point; `programs/<tool>.nix` is the "one file per tool" convention.
* `tools/<tool>/` — raw text dotfiles that `home.file` symlinks into `~/`.
* `setup.sh` — first-time bootstrap (Xcode CLT → Nix → CA bundle → flake host
  validation → /etc quarantine → darwin-rebuild → mise install → LSP global →
  prek).

For what each module owns (the six system-layer files / home-layer split),
see [README.md#tool-responsibilities](../README.md#tool-responsibilities).

## `~/` placement

Files that home-manager places via `home.file`:

* `.zshrc` `.tmux.conf` `.tmux_start_dir` `.markdownlint.jsonc` `.ctags.d/`
* `.config/{git,google-ime,mise,nvim}/` (XDG)
* `.claude/` (CLAUDE.md / settings.json / hooks/ / rules/ /
  mcp-servers.json / skills/.gitignore + dynamic areas projects/ todos/
  shell-snapshots/ statsig/ ide/)
* `.codex/` (config.toml is generated via pkgs.formats.toml then
  mutable-copied by activation / AGENTS.md → tools/codex/AGENTS.md
  (→ tools/claude/CLAUDE.md) symlink + dynamic areas sessions/ log.json;
  apm skills land in ~/.agents/skills/ instead)
* `.apm/` (apm.yml / apm.lock.yaml / .gitignore + dynamic areas
  apm_modules/ config.json / .claude/ / .github/)
* `.local/bin/tmux-start` (executable)
* `Library/Application Support/com.mitchellh.ghostty/config`
* `Library/Application Support/Code/User/{settings,keybindings}.json`

Dynamic areas (directories tools rewrite on their own) are intentionally
left outside `home.file` as mutable directories under `~/`. See
[design-philosophy.md#handling-dynamic-areas](design-philosophy.md#handling-dynamic-areas).

## Neovim

* Plugin manager: lazy.nvim (`~/.local/share/nvim/lazy/` is outside
  `home.file`; lazy.nvim owns that region).
* LSP / completion: nvim-lspconfig (new API `vim.lsp.config` +
  `vim.lsp.enable`) + nvim-cmp. For Ruby, presence of `gem "ruby-lsp"` in
  `Gemfile.lock` switches between `ruby_lsp` and `solargraph` exclusively
  (`tools/nvim/lua/plugins/lsp.lua`). Every server explicitly sets `cmd`,
  so when the binary is missing from PATH the server is skipped.
  LSP servers intentionally come from both Nix and `setup.sh` global installs
  under mise runtimes. Neovim only enables servers whose command exists on
  `PATH`, so missing servers are not spawned.
* Tree-sitter: nvim-treesitter on the main branch
  (`tools/nvim/lua/plugins/treesitter.lua`).
* Placement: `nix/home/programs/nvim.nix` symlinks the entire
  `tools/nvim/` into `~/.config/nvim` with a single out-of-store symlink
  (plugin payloads land in `~/.local/share/nvim/lazy/`, so the repo is
  never touched). `tools/nvim/lazy-lock.json` is tracked to guarantee
  reproducibility.
* Layout: `tools/nvim/init.lua` loads `lua/options.lua`,
  `lua/mappings.lua`, `lua/autocmds.lua`;
  `lua/plugins/{editor,ui,cmp,lsp,format,treesitter,lang}.lua` are
  lazy.nvim specs; `after/ftplugin/<lang>.lua` carries per-language
  local settings.
* Corporate-VPN SSL inspection workaround: the top of
  `tools/nvim/init.lua` injects `/etc/nix/ca-bundle.pem` into
  `GIT_SSL_CAINFO` / `CURL_CA_BUNDLE` / `SSL_CERT_FILE` so lazy.nvim's
  git clones and nvim-treesitter's curl parser downloads succeed. The
  deno LSP additionally requires `DENO_CERT`.

## Shell environment

* Shell: Zsh + starship prompt (`programs.starship.settings` is the
  declarative source of truth).
* mise's zsh integration is disabled (`enableZshIntegration = false`);
  `tools/zsh/.zshrc` carries a single hand-written
  `eval "$(mise activate zsh)"` line (starship is treated the same way).
  This is because `.zshrc` is placed as a raw-text symlink — letting
  home-manager inject into zshrc would collide.

## Claude Code

* The `claude` binary is installed into `~/.local/bin/claude` by the official
  native installer. It is treated as a mutable latest tool, not something
  rolled back by `flake.lock` or darwin generations.
* Only `tools/claude/skills/.gitignore` is tracked. Skills installed by
  APM (chrome-cdp, codebase-analyzer, ...) land under `~/.claude/skills/`
  and are ignored. The same skills are also deployed to the cross-agent
  `~/.agents/skills/` for codex (see Codex below).
* MCP servers are defined in `tools/mcp/servers.json`, the single source of
  truth shared with codex. Run `cd tools/claude && ./setup-mcp.sh` to expand
  them into Claude's user-scope mutable config via `claude mcp add` — this
  is **not** triggered automatically on apply.
* `rules/*.md` (`~/.claude/rules/` is auto-loaded by claude as user-level
  rules, no `@import` needed) holds markdown / nix / web-fetch / tools
  guidance. `nix.md` is scoped to `**/*.nix` via `paths:` frontmatter.
* `hooks/` holds PreToolUse destructive-command blocking
  (block-destructive-commands.py) and the PR gate (pr-review-gate.sh blocks
  `gh pr create` with exit 2 unless `/code-review` ran; pr-review-mark.sh
  sets the marker on PostToolUse(Skill)), plus PostToolUse markdownlint
  auto-fix.
* `settings.json` stays a raw symlink (live-editable). It carries `$schema`
  (schemastore) and the `claudeSettingsValidate` activation hook validates it
  with check-jsonschema on switch (non-blocking early detection of breakage;
  live-edit preserved).

For APM's install hook and the skill ingestion procedure, see
[README.md#claude-code-skills-via-apm](../README.md#claude-code-skills-via-apm).

## Codex

* The `codex` binary is installed into `~/.local/bin/codex` by the official
  native installer. Like Claude Code, it is treated as a mutable latest tool,
  not something rolled back by `flake.lock` or darwin generations.
* `~/.codex/config.toml` is generated from `settings` (a Nix attribute
  set) via `pkgs.formats.toml`, then the `codexConfig` activation hook
  writes it as a mutable real file (overwritten every switch). codex
  appends `[projects]` trust to config.toml at startup, so it cannot be a
  read-only symlink (the write fails with code -32603). After editing the
  settings you must `nix run .#switch`.
* MCP servers are read from `tools/mcp/servers.json` (shared with claude) by
  `codex.nix` via `builtins.fromJSON` and expanded into `mcp_servers` (single
  source of truth): `context7` and `terraform` only.
* Skills are deployed to the cross-agent `~/.agents/skills/` via
  `apm install --target claude,codex --global` in `apm.nix`, and codex
  auto-discovers them there (`~/.codex/skills/` holds only codex's built-in
  `.system` skills; `~/.agents/` is managed entirely by apm).
* `~/.codex/AGENTS.md` is an out-of-store symlink to `tools/codex/AGENTS.md`,
  which is itself an in-repo symlink to `../claude/CLAUDE.md`, so both tools
  share the same system instruction in a single file.
* `~/.codex/hooks.json` and `~/.codex/hooks/` are out-of-store symlinks to
  `tools/codex/`. The `PreToolUse` hook blocks destructive Bash commands using
  the same policy as Claude Code. Hooks supplement Codex's sandbox and approval
  policy; after changing them, review and trust them again with `/hooks`.
  Codex's `unified_exec` interception is currently incomplete, so this hook is
  a best-effort guardrail rather than the sole enforcement boundary.
* `~/.codex/rules/destructive.rules` is an out-of-store symlink to the managed
  Codex exec policy. Stable destructive prefixes such as `git reset --hard`
  are forbidden, while broader mutations such as `git push` require approval.
  These rules govern commands that request sandbox escape. The surrounding
  `~/.codex/rules/` directory remains mutable so Codex can maintain
  `default.rules`.
* Turn completion notifications use Codex's top-level `notify` command, while
  approval requests use `tui.notifications` when the terminal is unfocused.
  Claude's markdown auto-fix and pre-PR review gate are intentionally not
  mirrored because Codex does not expose equivalent reliable hook inputs and
  lifecycle events.

For the full secret-injection design, see
[design-philosophy.md#secrets-design](design-philosophy.md#secrets-design)
and [README.md#inject-secrets](../README.md#3-inject-secrets).

## VSCode

`tools/vscode/` holds the raw configs and `nix/home/programs/vscode.nix`
places them via home-manager:

* `settings.json` is generated in-store via `builtins.readFile +
  replaceStrings` so `${HOME}` resolves to `/Users/${user}` (jsonc
  comments are preserved).
* `keybindings.json` is an out-of-store symlink (direct edits + a reload
  apply immediately).
* Extensions are managed by the `home.activation.vscodeExtensions` hook,
  which idempotently diffs `extensions.txt` against
  `code --list-extensions`.

For day-to-day operation (sync.sh / picking up UI changes / SSL
inspection handling), see [docs/vscode-use.md](vscode-use.md).
