#!/bin/bash
set -ex

echo "Installing Xcode CLT..."
xcode-select --install || true

echo "Installing Rosetta..."
sudo softwareupdate --install-rosetta --agree-to-license || true

#------------------------------------------
# Nix + nix-darwin (replaces brew bundle)
#------------------------------------------
echo "Installing Nix (official installer)..."
if ! command -v nix >/dev/null 2>&1; then
    sh <(curl -L https://nixos.org/nix/installer)
fi

# Flakes 有効化
mkdir -p ~/.config/nix
grep -q "experimental-features = nix-command flakes" ~/.config/nix/nix.conf 2>/dev/null \
    || echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

echo "Applying nix-darwin (Homebrew, brews, casks, macOS defaults)..."
nix run nix-darwin -- switch --flake ".#$(scutil --get LocalHostName)"

#------------------------------------------
# chezmoi (dotfile management, replaces homesick link)
#------------------------------------------
echo "Initializing chezmoi..."
chezmoi init --apply --source "$(pwd)"

#------------------------------------------
# LSP servers (depends on mise-managed language runtimes)
#------------------------------------------
# `~/.tool-versions` に書かれた言語ランタイムを mise でまとめて install する。
# 失敗しても止めないのは、ビルド失敗してもセットアップ全体を最後まで回す方が
# 後段 (VSCode 等) を別途やり直さなくて済むため。
echo "Installing language runtimes from ~/.tool-versions via mise..."
mise install || true

# LSP server は npm/gem/go が走る言語でだけ事前 install しておく。
# `mise reshim` は npm install -g などで作った shim を再生成して PATH に
# 反映するために必要 (mise 経由の node なら自動だが、global install 直後は明示)。
echo "Installing LSP servers..."
npm install -g typescript-language-server typescript || true
npm install -g pyright || true
gem install ruby-lsp --no-doc || true
go install golang.org/x/tools/gopls@latest || true
mise reshim || true

#------------------------------------------
# VSCode
#------------------------------------------
echo "Setting up VSCode..."
if [ -f ./vscode/apply-settings.sh ]; then
    echo "Applying VSCode settings..."
    ./vscode/apply-settings.sh
fi

if [ -f ./vscode/sync-extensions.sh ]; then
    echo "Installing VSCode extensions..."
    ./vscode/sync-extensions.sh --install
fi

# Re-exec login shell so PATH and chezmoi-applied dotfiles take effect.
exec $SHELL -l
