# dotfiles

This is my setting files

## Before creating dotfiles directory in Github

    $ gem install homesick
    $ mkdir ~/dotfiles && cd ~/dotfiles
    $ git init
    $ mkdir home && cd home

    // if dotfiles are already existed in local, copy them to here
    $ cp ~/.vimrc .
    $ cp ~/.zshrc .
    $ cp ~/.tmux.conf .
    $ cp ~/brewfile .

    // for vim plugins
    $ mkdir .vim && cd .vim
    $ mkdir bundle && cd bundle
    $ git submodule add git@github.com:Shougo/neobundle.vim.git

    $ git add -A .
    $ git commit
    $ git remote add origin git@github.com:dangerousanimal/dotfiles.git
    $ git push -u origin master

## Using homesick
    $ gem install homesick
    $ homesick clone dangerousanimal/dotfiles
    $ cd ~ && homesick symlink dotfiles

## If dotfiles are updated
    // in current pc
    $ cd ~/.homesick/repos/dotfiles
    $ git add -A .
    $ homesick commit dotfiles
    $ homesick push dotfiles

    // in other pc
    $ homesick pull dotfiles
    $ cd ~ && homesick symlink dotfiles

