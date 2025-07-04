# Dotfiles

## Requirements

- [homesick](https://github.com/technicalpickles/homesick)

## Get started

```shell
# Prepare dotfiles environment in your local
$ mkdir -p ~/.homesick/repos && cd ~/.homesick/repos
$ git clone git@github.com:danimal141/dotfiles.git

# Setup
$ ./setup.sh

# Sync dotfiles
$ homesick link dotfiles
```

### Share coc-settings for nvim

```
# Manage coc-settings under .vim and share the symlink under .config/nvim
$ ln -s ~/.vim/coc-settings.json ~/.config/nvim
```
