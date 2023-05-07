#!/bin/bash

echo "Installing Xcode..."
xcode-select --install

# Install rosetta
# echo "Installing rosetta..."
# sudo softwareupdate --install-rosetta --agree-to-licensesudo softwareupdate --install-rosetta --agree-to-license

#------------------------------------------
# homebrew (arm64)
#------------------------------------------
echo "Installing homebrew..."
which /opt/homebrew/bin/brew >/dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo "Execute brew doctor..."
which /opt/homebrew/bin/brew >/dev/null 2>&1 && brew doctor

echo "Execute brew update..."
which /opt/homebrew/bin/brew >/dev/null 2>&1 && brew update --verbose

echo "Execute brew upgrade..."
which /opt/homebrew/bin/brew >/dev/null 2>&1 && brew upgrade --verbose

echo "Installing packages written in Brewfile..."
which /opt/homebrew/bin/brew >/dev/null 2>&1 && brew bundle --file ./home/Brewfile --verbose

echo "Execute brew cleanup..."
which brew >/dev/null 2>&1 && brew cleanup --verbose

echo "Installing programming languages..."
./_asdf.sh

echo "Installing homesick..."
gem install homesick --no-doc

echo "Symlink dotfiles..."
homesick link dotfiles

# Replace the current shell with a new shell, run it as a login shell, and reset the environment settings.
exec $SHELL -l
