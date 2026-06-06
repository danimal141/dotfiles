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
# を public repo に出さない設計。詳細は README-ja.md の「業務 git identity
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
      # 社内 VPN SSL inspection 下で git の TLS 検証を通すため、Nix が配置する
      # CA bundle (/etc/nix/ca-bundle.pem) を git に渡す。brew update が内部で
      # 呼ぶ git fetch や ghq clone など全 git 経路に効く。bundle が無い環境
      # では git が失敗するが、本 dotfiles は VPN 配下の業務マシン前提。
      http = {
        sslCAInfo = "/etc/nix/ca-bundle.pem";
      };
    };

    ignores = [
      ".DS_Store"
      "tags"
      ".tags"
      "*.code-workspace"
      "**/.claude/reports/"
      "**/.claude/settings.local.json"
      ".serena/"
    ];

    includes = [
      # 条件分岐込みで全部 user 側 (~/.gitconfig.local) に逃がす。詳細は
      # README-ja.md「業務 git identity 上書き」セクション参照。
      { path = "~/.gitconfig.local"; }
    ];
  };
}
