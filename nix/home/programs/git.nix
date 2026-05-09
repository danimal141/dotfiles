{ gitName, gitEmail, ... }:

# `~/.gitconfig` を home-manager の `programs.git` で declarative に管理する。
#
# identity (gitName / gitEmail) は flake.nix の hosts attrset から
# specialArgs 経由で流れてくる。マシン追加時は hosts に 1 entry 足すだけで
# identity も自動で反映される。
#
# 業務用の identity 上書きは `~/.gitconfig.local` (user 手書き、repo 外、
# tracked しない) を unconditional に include する経路で実現する。条件分岐
# (どの remote URL pattern で identity を切り替えるか) と上書き値そのもの
# (~/.gitconfig.work) の双方を user 側に逃がして、所属組織名や業務メール
# を public repo に出さない設計。詳細は README.md の「業務 git identity
# 上書き」セクション参照。
#
# global gitignore は `programs.git.ignores` で ~/.config/git/ignore に
# XDG 配置する。git は core.excludesfile が未設定なら XDG default を自動で
# 読むため excludesfile の手書きは不要。
{
  programs.git = {
    enable = true;

    # home-manager 26.05 で `userName` / `userEmail` / `extraConfig` は
    # `programs.git.settings.*` に統合された。settings は `~/.gitconfig`
    # の section を attrset として直接表現する。
    settings = {
      user = {
        name = gitName;
        email = gitEmail;
      };
      core = {
        editor = "nvim";
      };
      diff = {
        ignoreSubmodules = "dirty";
      };
    };

    ignores = [
      ".DS_Store"
      "tags"
      ".tags"
      "*.code-workspace"
      "**/.claude/reports/"
      ".serena/"
    ];

    includes = [
      # 条件分岐込みで全部 user 側 (~/.gitconfig.local) に逃がす。詳細は
      # README.md「業務 git identity 上書き」セクション参照。
      { path = "~/.gitconfig.local"; }
    ];
  };
}
