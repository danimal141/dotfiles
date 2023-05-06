#!/bin/sh

# install programming languages

# Function to install a programming language using asdf
install_language() {
  local lang=$1
  which asdf >/dev/null 2>&1 && asdf plugin add "${lang}" && asdf install "${lang}" latest && asdf global "${lang}" latest
}

# install programming languages
languages=("ruby" "nodejs" "python" "golang" "rust" "terraform" "kubectl")

for lang in "${languages[@]}"; do
  echo "Start installing ${lang}..."
  install_language "${lang}"
done
