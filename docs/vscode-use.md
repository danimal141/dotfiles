# VSCode Settings Management

English | [日本語](vscode-use-ja.md)

VSCode's `settings.json` / `keybindings.json` / extensions are placed
and installed by home-manager (`nix/home/programs/vscode.nix`) via the
`darwin-rebuild` activation path. Drop the raw config under
`tools/vscode/` and a single `nix run .#switch` keeps everything in
sync.

## File layout

* `tools/vscode/settings.jsonc` — VSCode user settings (jsonc, contains
  `${HOME}` placeholders)
* `tools/vscode/keybindings.jsonc` — keybindings (jsonc)
* `tools/vscode/extensions.txt` — list of extension IDs to install
* `tools/vscode/sync.sh` — extension sync utility (`--save` /
  `--status`)
* `nix/home/programs/vscode.nix` — the home-manager module that reads
  the above and places files under
  `~/Library/Application Support/Code/User/`

## Placement patterns

### settings.json

Read `tools/vscode/settings.jsonc` via
`builtins.readFile + builtins.replaceStrings`, replace `${HOME}` with
`/Users/${user}`, and generate it in-store via
`home.file."<path>".text`.

* jsonc comments (`// ...`) are preserved as raw strings
* `${user}` is resolved per host via `mkHost`'s specialArgs in
  `flake.nix`
* After editing, **`nix run .#switch` is required** (re-eval of `text =`
  is needed)
* `~/Library/Application Support/Code/User/settings.json` becomes a
  symlink to `/nix/store/...-home-manager-files/...`

### keybindings.json

`mkOutOfStoreSymlink` puts an out-of-store symlink to
`tools/vscode/keybindings.jsonc` at
`~/Library/Application Support/Code/User/keybindings.json`. No
per-host resolution like `${HOME}` is needed for keybindings.

* Reflects immediately:
  `nvim ~/Library/Application\ Support/Code/User/keybindings.json`
  lets you edit the repo file directly. VSCode detects the change and
  reloads (Cmd+R for explicit reload)
* No `nix run .#switch` needed

### extensions

The `home.activation.vscodeExtensions` hook does:

1. Walk through `tools/vscode/extensions.txt` line by line
2. Compare against the output of `code --list-extensions`
3. Fire `code --install-extension <id> --force` only for the missing
   ones

Idempotent — running `nix run .#switch` does nothing when everything is
already installed. When `code` is missing from PATH (= VSCode not
installed), the hook is skipped and the overall switch is not blocked.

For corporate VPN SSL inspection (MITM CA), the hook exports
`NODE_EXTRA_CA_CERTS=/etc/nix/ca-bundle.pem`. On a personal Mac without
the bundle, it stays unset (Node's default CA is used).

## Operations

### Initial setup (new Mac)

After `setup.sh` completes, settings / keybindings / extensions are all
placed automatically via the `darwin-rebuild` activation path. No need
to invoke `apply-settings.sh` or similar by hand.

### Editing settings.json

```bash
$EDITOR tools/vscode/settings.jsonc
nix run .#switch
```

### Editing keybindings.json

```bash
$EDITOR tools/vscode/keybindings.jsonc
# VSCode auto-reloads (or Cmd+R for explicit reload)
```

You can edit `tools/vscode/keybindings.jsonc` directly, or edit
`~/Library/Application Support/Code/User/keybindings.json` from inside
VSCode — both modify the in-repo file (it is an out-of-store symlink).

### Adding a new extension

```bash
# Install the extension via the VSCode UI (Cmd+Shift+X)
cd tools/vscode && ./sync.sh --save   # write the actual state back into extensions.txt
git diff extensions.txt               # review the change and commit
```

Other Macs pick the new extension up on the next `nix run .#switch`.

### Checking sync status

```bash
cd tools/vscode && ./sync.sh --status
```

Lists extensions installed in VSCode but missing from
`extensions.txt`, those listed in `extensions.txt` but not installed,
and those already in sync.

### Custom Shortcuts (current contents of keybindings.jsonc)

* **Cmd+Shift+L** (when terminal is focused): toggle panel maximize
* **Cmd+Shift+W**: focus Workspace Explorer
* **Cmd+Shift+C**: collapse all folders in Explorer

To add a new keybinding, use the VSCode Keyboard Shortcuts editor
(Cmd+K Cmd+S) to check the syntax and append it to
`tools/vscode/keybindings.jsonc`. It is jsonc, so comments are fine.

## Platform support

macOS only. The Linux path `~/.config/Code/User/` is not handled by
the home-manager module (the whole repo is macOS-only).
