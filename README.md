# Dotfiles

English | [日本語](README-ja.md)

Personal dotfiles that manage macOS system settings, Homebrew, and dotfiles
declaratively with `nix-darwin` + `home-manager`. Everything is applied with a
single command: `nix run .#switch` (which internally invokes
`darwin-rebuild switch --flake ".#<host>"`).

See [docs/design-philosophy.md](docs/design-philosophy.md) for the design
rationale.

## Requirements

* macOS (Apple Silicon, Sonoma or later)
* [Nix + nix-darwin](https://github.com/nix-darwin/nix-darwin) — declaratively
  manages Homebrew, macOS settings, Nix store CLIs, and home-manager dotfiles
  all together

## Get started

### 1. Clone the repository

The clone location is arbitrary, but the modules in this repo hardcode the
absolute path `/Users/<user>/Documents/dev/dotfiles`. If you place it
elsewhere, update `dotfilesPath` in `nix/home/programs/*.nix`:

```shell
git clone git@github.com:danimal141/dotfiles.git ~/Documents/dev/dotfiles
cd ~/Documents/dev/dotfiles
```

### 2. Run `setup.sh`

```shell
./setup.sh             # auto-detect flake host from LocalHostName
./setup.sh work        # explicitly target the work Mac
./setup.sh personal    # explicitly target the personal Mac
```

What `setup.sh` does:

1. Install Xcode CLT (Apple Silicon only — Rosetta is not installed)
2. Run the official Nix upstream installer (skipped if already installed)
3. Bake a CA bundle from the macOS Keychain into `/etc/nix/ca-bundle.pem` and
   hand it to the nix-daemon via `launchctl setenv` (workaround for corporate
   VPN SSL inspection; harmless on personal Macs)
4. Move `/etc/bashrc` and `/etc/nix/nix.conf` (written by the Nix installer) to
   `*.before-nix-darwin` so that nix-darwin's activation does not abort due to
   "unrecognized content"
5. Run `sudo -E nix run nix-darwin -- switch --flake ".#<hostname>"` —
   `nix/darwin/{macos-defaults,keyboard,nix-daemon,system,packages,homebrew}.nix`
   (system layer / Nix store CLIs / brew / cask) and `nix/home/programs/*.nix`
   (dotfile symlinks via home-manager, including VSCode settings / keybindings
   / extensions) are applied in one go
6. Run `mise install` to install the actual binaries declared in
   `~/.config/mise/config.toml`
7. Globally install LSP servers (typescript / pyright / ruby-lsp / gopls)
8. Run `prek install` to idempotently install `.git/hooks/pre-commit`
   (secretlint hook)
9. `exec $SHELL -l` to switch to a fresh login shell

After completion, `which git` resolves to
`/etc/profiles/per-user/<user>/bin/git` or
`/run/current-system/sw/bin/git`.

### 3. Inject secrets

The repo is public — secrets are not tracked. Three injection paths:

#### codex (`GEMINI_API_KEY`)

User-placed `~/.codex/.env`:

```shell
cp tools/codex/.env.example ~/.codex/.env
chmod 600 ~/.codex/.env
$EDITOR ~/.codex/.env       # fill in GEMINI_API_KEY=...
```

`tools/codex/wrappers/gemini-mcp.sh` (symlinked to
`~/.codex/wrappers/gemini-mcp.sh`) sources `.env` at startup and injects the
env into the `mcp-gemini-google-search` child process.

#### Claude Code MCP server env (optional)

When you run `tools/claude/setup-mcp.sh` as
`cd tools/claude && ./setup-mcp.sh`, the script sources `.env` in the
same directory and injects the values as the `env:` of each server in
`tools/claude/mcp-servers.yaml`. Right now the registered servers
(context7 / terraform) both have `env: {}`, so the path can be safely
skipped — but when you add a server that requires env vars:

```shell
cp tools/claude/.env.example tools/claude/.env
chmod 600 tools/claude/.env
$EDITOR tools/claude/.env   # fill in GITHUB_PERSONAL_ACCESS_TOKEN=... etc.
cd tools/claude && ./setup-mcp.sh
```

`tools/claude/.env` is excluded by the repo's `.gitignore`; only
`.env.example` is tracked.

#### Work GitHub org git identity (optional)

Work identity overrides use **two user-handwritten files**. The design keeps
both the conditional logic (which remote URL pattern flips the identity) and
the override values (name / email) on the user side, so neither the
organization name nor the work email appears in this public repo.

The repo's `programs.git.includes` simply includes `~/.gitconfig.local`
unconditionally (without knowing its contents). The actual conditional logic
is written by the user inside `~/.gitconfig.local` as
`[includeIf "..."]` blocks, and the included `~/.gitconfig.work` holds the
identity — a two-layer split.

| File | Role | Content |
|---|---|---|
| `~/.gitconfig.local` | dispatcher: declares which remote URL pattern flips to work identity | `[includeIf "hasconfig:remote.*.url:git@github.com:<your-org>/**"]` blocks |
| `~/.gitconfig.work` | overrides: the name / email applied after switch | `[user] name = ... / email = ...` |

Neither file is tracked by the repo or by git (= absent on personal Macs,
present only on work Macs as handwritten files).

##### Work Mac setup

```shell
# 1. Create the dispatcher (write the org pattern in one line)
$ cat > ~/.gitconfig.local <<'EOF'
[includeIf "hasconfig:remote.*.url:git@github.com:<your-org>/**"]
    path = ~/.gitconfig.work
[includeIf "hasconfig:remote.*.url:https://github.com/<your-org>/**"]
    path = ~/.gitconfig.work
EOF
$ chmod 600 ~/.gitconfig.local

# 2. Create the overrides (work identity values)
$ cat > ~/.gitconfig.work <<'EOF'
[user]
    name  = Your Work Name
    email = you@example.com
EOF
$ chmod 600 ~/.gitconfig.work
```

Replace `<your-org>` with the actual GitHub org name and
`Your Work Name` / `you@example.com` with the work identity.

##### Verification

```shell
cd <clone of a work-org repo>
git config user.email   # → work email (if .gitconfig.local + .gitconfig.work are in place)
cd <this dotfiles repo>
git config user.email   # → personal email (declared in flake.nix)
```

### 4. pre-commit + secretlint

To prevent accidental API key commits, secretlint is wired into the
pre-commit hook. `prek` (a Rust implementation of pre-commit, drop-in
compatible) is shipped via `nix/darwin/packages.nix`, and `setup.sh`
auto-runs `prek install` at the end. Manual reinstall:

```shell
prek install              # install .git/hooks/pre-commit
prek run --all-files      # run once across all existing files (optional)
```

secretlint itself and the rule preset are pinned in `package.json` /
`package-lock.json`; `setup.sh`'s `npm ci` installs them into
`node_modules/`, and the hook invokes `npx secretlint` to reference them.

### Troubleshooting

* **Nix SSL error (`self-signed certificate in certificate chain`)** —
  Verify that `setup.sh` step 3 has run (`/etc/nix/ca-bundle.pem` is at
  least 100 KB). If corporate IT has just pushed a new CA to the Keychain,
  regenerate the bundle (`sudo bash -c "security find-certificate -a -p
  /Library/Keychains/System.keychain >> /etc/nix/ca-bundle.pem ..." && sudo
  launchctl kickstart -k system/org.nixos.nix-daemon`)
* **`darwin-rebuild` aborts with "unrecognized content in /etc/..."** —
  Move the offending file to `.before-nix-darwin` and rerun
* **Homebrew formula / cask name resolution fails during `darwin-rebuild`'s
  Homebrew step** — Update `nix/darwin/homebrew.nix` if upstream has
  renamed or cask-ified something
* **In a work repo, `git config user.email` still shows the personal
  identity** — `~/.gitconfig.local` or `~/.gitconfig.work` is missing, or
  the remote URL does not match the `hasconfig:remote.*.url:` condition in
  `~/.gitconfig.local`. Check the URL with `git remote -v` and verify the
  org pattern in `.gitconfig.local` and the existence of `.gitconfig.work`

## Day-to-day operations

### nix-darwin (system / Homebrew / dotfile all in one)

| Action | Command |
|---|---|
| Apply config changes (system / brew / home-manager) | `nix run .#switch` |
| Build only (verify before applying) | `nix run .#build` |
| Update every input in `flake.lock` | `nix run .#update` |
| Add / remove a Nix store CLI | Edit `nix/darwin/packages.nix` → switch above |
| Add / remove Homebrew brew / cask | Edit `nix/darwin/homebrew.nix` → switch above |
| Tweak macOS settings (Dock / Finder / NSGlobalDomain etc.) | Edit `nix/darwin/macos-defaults.nix` → switch above |
| Change keyboard remap / input source shortcut | Edit `nix/darwin/keyboard.nix` → switch above |
| Tweak Nix daemon / GC / SSL CA bundle / env vars | Edit `nix/darwin/nix-daemon.nix` → switch above |
| Edit a user-layer dotfile or `programs.*` | Edit `nix/home/programs/<tool>.nix` → switch above (raw text symlinks reflect immediately without switching) |
| Update a single flake input | `nix flake update <input>` (e.g., `nixpkgs` / `nix-darwin` / `nix-homebrew` / `home-manager`) |
| List generations | `darwin-rebuild --list-generations` |
| Roll back to previous generation | `darwin-rebuild --rollback` |

`nix run .#<app>` is a shell wrapper defined under
`apps.aarch64-darwin.*` in `flake.nix`. Internally it invokes
`darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"` (so a raw
`darwin-rebuild` invocation is equivalent). The wrapper adds three things:

* Auto-resolves the host via `scutil --get LocalHostName` (= one command
  covers `work` / `personal`)
* When run from a TTY, formats progress with `nix-output-monitor` (nom);
  falls back to raw output when an AI agent env (`CLAUDECODE` /
  `CODEX_SANDBOX` / etc.) is detected
* Resolves `darwin-rebuild` via an absolute path from the flake input, so
  it works during initial bootstrap when `/run/current-system/sw/bin/...`
  is not yet populated

Main reasons for keeping things on the Homebrew side in
`nix/darwin/homebrew.nix`:

* Tap-only formulae (argoproj/tap/argocd, fujiwara/tap/tfstate-lookup,
  kayac/tap/ecspresso, mutagen-io/mutagen/mutagen-compose, etc.)
* Apple / macOS integration is more reliable via brew (basictex, ffmpeg,
  imagemagick, llvm, mas)
* CLIs that assume a Node / Python runtime (markdownlint-cli, marp-cli,
  repomix, pipx)
* macOS-only tools (terminal-notifier, im-select)
* Shell and plugins (zsh / zsh-autosuggestions / zsh-syntax-highlighting /
  zsh-completions) — startup is faster via brew

Caveats:

* `nix run .#update` (= `nix flake update`, updates every input) makes
  bisection hard when something breaks. When that happens, switch to a
  named single-input update (`nix flake update <input>`)
* nixpkgs lag can temporarily break `darwin-rebuild`. If it stops working,
  use `--rollback` to revert to the previous generation, then `git`-revert
  `flake.lock` and switch again

### Editing / adding dotfiles

Dotfiles placed via raw text symlinks (zsh / tmux / nvim / claude /
ghostty / ctags / mise config.toml / markdownlint) are **edited by opening
the repo file directly** (`nvim ~/.zshrc`):

```shell
$ readlink ~/.zshrc
# → /Users/<user>/Documents/dev/dotfiles/tools/zsh/.zshrc (reaches the repo via a 3-step chain)
$ nvim ~/.zshrc           # ← you are editing repo's tools/zsh/.zshrc
$ source ~/.zshrc         # reflects immediately (no nix run .#switch needed)
```

Files generated via `text =` or `programs.<tool>.settings` (codex
config.toml / git / starship etc.) require editing
`nix/home/programs/<tool>.nix` and running `nix run .#switch`.

For adding new dotfiles, see "Managing Dotfiles" in CLAUDE.md.

### mise (language runtime)

The global declaration source is `~/.config/mise/config.toml` (= an
out-of-store symlink to the repo's `tools/mise/config.toml` via
home-manager). Per-project overrides go in `<project>/mise.toml` or
`<project>/.tool-versions` (asdf-compatible).

Resolution priority (higher wins):

1. `<project>/mise.toml` | `<project>/.mise.toml`
2. `<project>/.tool-versions`
3. `~/.config/mise/config.toml` (= global via home-manager)

| Action | Command |
|---|---|
| Install every declared runtime | `mise install` |
| Pin a per-project version | `mise use ruby@3.4 --pin` |
| Update a global version | Edit `tools/mise/config.toml` directly (= `nvim ~/.config/mise/config.toml`) |
| Regenerate shims for LSP etc. | `mise reshim` |
| List available versions | `mise ls-remote ruby` |

Caveats:

* `mise use -g <pkg>` directly modifies the repo's
  `tools/mise/config.toml`, so the change is visible in `git diff`. Commit
  it when you feel like it, and the change propagates across all Macs
* mise activate injects its shims at the head of `PATH`, so place
  `mise activate zsh` in `zshrc` **after** `path-helper` and the Nix-side
  runtimes

## Adding a new Mac

Hostname convention: `work` for the work machine, `personal` /
`personal2` / ... for personal machines. The `networking.hostName` in
`nix/darwin/hosts/<hostname>.nix` is enforced during apply, so the
original hostname assigned by corporate IT gets overwritten.

### 1. Add an entry to the `hosts` attrset in `flake.nix`

```nix
hosts = {
  "work"      = { user = "hideaki.ishii"; gitName = "danimal141"; gitEmail = "..."; };
  "personal"  = { user = "danimal141";    gitName = "danimal141"; gitEmail = "..."; };
  "personal2" = { user = "danimal141";    gitName = "danimal141"; gitEmail = "..."; };  # ← added
};
```

### 2. Create `nix/darwin/hosts/<hostname>.nix` (use `work.nix` as a template)

```nix
{ ... }:
{
  networking.hostName = "personal2";
  # host-specific brew / cask, if any, goes here
}
```

### 3. Commit & push the change

### 4. Run setup on the new Mac

```shell
./setup.sh personal2     # ← always pass the flake host as the first arg
```

On a fresh Mac, the LocalHostName is still whatever corporate IT assigned,
so `scutil --get LocalHostName` does not return the new host name and
`setup.sh` falls back to `work`. **On a personal Mac, forgetting the
argument causes a `work` switch**, so always pass the first arg
explicitly. After `darwin-rebuild` completes, the LocalHostName is
rewritten to `<hostname>`, so subsequent runs of `./setup.sh` (no
argument) work fine.

## Tool responsibilities

* nix-darwin (system layer, pinned via `flake.lock`, consolidated under
  `nix/darwin/`):
  * `nix/darwin/packages.nix` — CLI binaries from the Nix store (git /
    tmux / neovim / fzf / ripgrep / jq / gh / kubectl family / apm etc.)
  * `nix/darwin/homebrew.nix` — Tap-only formulae / GUI casks / formulae
    with strong macOS integration
  * `nix/darwin/macos-defaults.nix` — `system.defaults.*` (Dock / Finder /
    NSGlobalDomain (KeyRepeat / autocomplete off etc.) / trackpad /
    WindowManager / menuExtraClock / CustomUserPreferences for Kotoeri /
    language etc.)
  * `nix/darwin/keyboard.nix` — `system.keyboard` for the CapsLock →
    Control HID remap, `launchd.user.agents.remap-caps-lock` for
    reapplying at login across reboots,
    `system.activationScripts.postActivation` for targeted updates of the
    input source switch shortcut (`AppleSymbolicHotKeys` IDs 60/61)
  * `nix/darwin/nix-daemon.nix` — `nix.settings` (experimental-features /
    trusted-users / SSL CA bundle), `nix.gc`,
    `environment.variables` (NIX_SSL_CERT_FILE /
    HOMEBREW_FORBIDDEN_FORMULAE)
  * `nix/darwin/system.nix` — `system.primaryUser` / `users.users.<user>`
    / `programs.zsh.enable = false` / `system.stateVersion` residuals
  * `nix/darwin/default.nix` — bundles the six files above via imports.
    `flake.nix` imports `./nix/darwin` once and gets everything
  * `nix/darwin/hosts/<hostname>.nix` — per-host overrides
    (`networking.hostName` enforcement + host-specific brew packages)
* home-manager (user layer, integrated as a nix-darwin module):
  * `nix/home/programs/<tool>.nix` — one file per tool. Places files under
    `~/` either as a raw text symlink (`mkOutOfStoreSymlink`) or via a
    declarative module (`programs.<tool>.settings`)
  * Binaries land under `/etc/profiles/per-user/$USER/bin/`
* mise (language runtimes):
  * Declaration source is `~/.config/mise/config.toml` (= the repo's
    `tools/mise/config.toml` via home-manager). `mise install` reads it
    and materializes binaries under `~/.local/share/mise/installs/`
* Out of repo control (dynamic areas / secrets):
  * `~/.claude/{projects,todos,shell-snapshots,statsig,ide}/` (Claude
    Code dynamic area)
  * `~/.codex/{sessions,log.json}` (codex dynamic area)
  * `~/.apm/{apm_modules,config.json,.claude,.github}` (APM dynamic area)
  * `~/.local/share/nvim/{lazy,site/parser}/` (lazy.nvim and
    nvim-treesitter dynamic areas)
  * `~/.codex/.env`, `~/.gitconfig.local`, `~/.gitconfig.work` (secrets /
    org name; user-handwritten)

PATH resolution order (`tools/zsh/.zshrc`):

1. `/etc/profiles/per-user/$USER/{bin,sbin}` — home-manager user profile
2. `/run/current-system/sw/{bin,sbin}` — nix-darwin system profile
3. `/opt/homebrew/{bin,sbin}` — Homebrew (formulae / casks outside the
   Nix migration)
4. `$HOME/bin`, `$HOME/.local/bin`
5. mise activate then injects language runtime shims at the head of PATH

The home-manager user profile sits before the system profile so that
when both have a binary with the same name, the home-manager side
(= pinned by `flake.lock`) wins.

## Claude Code skills via APM

Claude Code skills live in
[skilltree](https://github.com/danimal141/skilltree), pulled in via
[APM (Agent Package Manager)](https://github.com/microsoft/apm).

During `nix run .#switch`, the `home.activation.apmInstall` hook compares
the sha256 of `~/.apm/apm.yml` and fires `apm install --target claude`
only when the file changed (idempotent). To rerun manually:

```shell
cd ~/.apm
apm install --target claude
```

To add or remove a skill, edit `tools/apm/apm.yml` (in-repo source for the
symlink at `~/.apm/apm.yml`) and run `nix run .#switch`.
