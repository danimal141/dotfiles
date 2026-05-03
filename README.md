# Dotfiles

## Requirements

* [homesick](https://github.com/technicalpickles/homesick)

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

## Claude Code skills via APM

Claude Code のスキル群は [skilltree](https://github.com/danimal141/skilltree) にまとめ、
[APM (Agent Package Manager)](https://github.com/microsoft/apm) 経由で取り込む。

```shell
# 1. APM CLI を含む Brewfile の依存をインストール
$ brew bundle --file=~/Brewfile

# 2. ~/.apm/apm.yml は dotfiles で管理されているので、homesick link 後にそのまま使える
$ apm install -g

# 3. スキルが ~/.claude/skills/ に展開される
$ ls ~/.claude/skills/
```

依存スキルを追加・削除する場合は `~/.apm/apm.yml`（実体は `home/.apm/apm.yml`）を編集して
`apm install -g --update` を実行する。
