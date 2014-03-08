# dotfiles

This is my setting files

## First setting before creating dotfiles directory in Github
    
    $ gem install homesick
    $ mkdir ~/dotfiles && cd ~/dotfiles
    $ git init
    $ mkdir home && cd home

    // if dotfiles are already existed, copy them to here
    $ cp ~/.vimrc .
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
    
## Using in other PC
    $ gem install homesick
    $ homesick clone dangerousanimal/dotfiles
    $ cd ~ && homesick symlink dotfiles
    
## If dotfiles are updated
    $ homesick pull dotfiles
    $ homesick symlink dotfiles

