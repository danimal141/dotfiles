#!/bin/bash
set -ex

echo "Installing Xcode..."
xcode-select --install || true

# Install rosetta
echo "Installing rosetta..."
sudo softwareupdate --install-rosetta --agree-to-licensesudo softwareupdate --install-rosetta --agree-to-license || true

#------------------------------------------
# homebrew (arm64)
#------------------------------------------
echo "Installing homebrew..."
which /opt/homebrew/bin/brew >/dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# PATH for brew
echo "Add PATH for homebrew..."
export PATH="/opt/homebrew/bin:$PATH" && which brew

echo "Execute brew doctor..."
brew doctor

echo "Execute brew update..."
brew update --verbose

echo "Execute brew upgrade..."
brew upgrade --verbose

echo "Installing packages written in Brewfile..."
brew bundle --file ./home/Brewfile --verbose

echo "Execute brew cleanup..."
brew cleanup --verbose

#------------------------------------------
# asdf
#------------------------------------------
echo "Installing programming languages..."
./_asdf.sh

#------------------------------------------
# homesick
#------------------------------------------
echo "Installing homesick..."
gem install homesick --no-doc

echo "Symlink dotfiles..."
homesick link dotfiles

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

# Replace the current shell with a new shell, run it as a login shell, and reset the environment settings.
exec $SHELL -l
