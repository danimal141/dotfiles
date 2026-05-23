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
* `setup.sh` — first-time bootstrap (Xcode CLT → Nix → CA bundle → /etc
  quarantine → darwin-rebuild → mise install → LSP global → prek).

For what each module owns (the six system-layer files / home-layer split),
see [README.md#tool-responsibilities](../README.md#tool-responsibilities).

## `~/` placement

Files that home-manager places via `home.file`:

* `.zshrc` `.tmux.conf` `.tmux_start_dir` `.markdownlint.jsonc` `.ctags.d/`
* `.config/{git,mise,nvim}/` (XDG)
* `.claude/` (CLAUDE.md / settings.json / hooks/ / rules/ /
  mcp-servers.yaml / skills/.gitignore + dynamic areas projects/ todos/
  shell-snapshots/ statsig/ ide/)
* `.codex/` (config.toml is text-generated / wrappers / AGENTS.md →
  tools/claude/CLAUDE.md symlink + dynamic areas sessions/ log.json)
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

* Only `tools/claude/skills/.gitignore` is tracked. Skills installed by
  APM (chrome-cdp, codebase-analyzer, ...) land under `~/.claude/skills/`
  and are ignored.
* MCP servers are declared by hand in `tools/claude/mcp-servers.yaml`.
  Run `cd tools/claude && ./setup-mcp.sh` to expand them into
  `~/.claude/mcp.json` — this is **not** triggered automatically on apply.

For APM's install hook and the skill ingestion procedure, see
[README.md#claude-code-skills-via-apm](../README.md#claude-code-skills-via-apm).

## Codex

* `~/.codex/config.toml` is generated via home-manager's `text =` (the
  `user` variable interpolates the wrapper's absolute path). This loses
  the "edit and reload" experience — after editing you must
  `nix run .#switch`.
* `GEMINI_API_KEY` lives in `~/.codex/.env` (gitignored, user-placed by
  hand). The wrapper (`tools/codex/wrappers/gemini-mcp.sh`) sources it
  at launch and injects it as the env for `mcp-gemini-google-search`.
* `~/.codex/AGENTS.md` is an out-of-store symlink to
  `tools/claude/CLAUDE.md` (both tools share the same system instruction).

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
