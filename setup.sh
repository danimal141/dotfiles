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
# LSP servers (depends on asdf/mise runtimes - mise migration is Step mise)
#------------------------------------------
echo "Installing programming language runtimes via asdf..."
./_asdf.sh

echo "Installing LSP servers..."
npm install -g typescript-language-server typescript || true
npm install -g pyright || true
gem install ruby-lsp --no-doc || true
go install golang.org/x/tools/gopls@latest || true
asdf reshim nodejs || true
asdf reshim ruby || true
asdf reshim golang || true

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
