# Dotfiles

## Requirements

- [homesick](https://github.com/technicalpickles/homesick)

## Get started

### Preparation

```
$ gem install homesick
$ mkdir ~/dotfiles && cd ~/dotfiles
$ git init
$ mkdir home && cd home

# If dotfiles already exist in your local, copy them to here.
$ cp ~/.vimrc .
$ cp ~/.zshrc .
$ cp ~/.tmux.conf .
$ cp ~/brewfile .

# For managing vim plugins
$ mkdir -p .vim
$ curl -fLo ${ROOT_DIR}/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

$ git add -A .
$ git commit
$ git remote add origin YOUR_REPOSITORY
$ git push -u origin master
```

### How to use with homesick

```
$ homesick clone danimal141/dotfiles
$ homesick symlink dotfiles
```

### When dotfiles are updated

```
# In current PC
$ cd ~/.homesick/repos/dotfiles
$ git add -A .
$ homesick commit dotfiles
$ homesick push dotfiles

# In another PC
$ homesick pull dotfiles
$ homesick symlink dotfiles
```
