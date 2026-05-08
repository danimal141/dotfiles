{ gitName, gitEmail, ... }:

# `~/.gitconfig` を home-manager の `programs.git` で declarative に管理する。
#
# identity (gitName / gitEmail) は flake.nix の hosts attrset から specialArgs
# 経由で流れてくる (Phase 2 で配線済み)。マシン追加時は hosts に 1 entry
# 足すだけで identity も自動で反映される。
#
# 業務 (speee org) の remote URL を持つ repo だけ ~/.gitconfig.work で上書き
# する経路は includeIf で再現する。`~/.gitconfig.work` は git でも repo でも
# 追跡しない手書きファイル (public repo に業務メールを焼かない意図)。
# `hasconfig:remote.*.url:` でマッチするので clone path に依存しない
# (yxtay/dotfiles に倣う)。
#
# `~/.gitignore` (global gitignore) は引き続き chezmoi 配置を借りる。
# Phase 3 後段で home.file に移植する想定。
{
  programs.git = {
    enable = true;
    userName = gitName;
    userEmail = gitEmail;

    extraConfig = {
      core = {
        excludesfile = "~/.gitignore";
        editor = "nvim";
      };
      diff = {
        ignoreSubmodules = "dirty";
      };
    };

    includes = [
      {
        condition = "hasconfig:remote.*.url:git@github.com:speee/**";
        path = "~/.gitconfig.work";
      }
      {
        condition = "hasconfig:remote.*.url:https://github.com/speee/**";
        path = "~/.gitconfig.work";
      }
    ];
  };
}
