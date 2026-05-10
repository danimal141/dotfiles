{ config, user, dotfilesPath, ... }:

# VSCode 設定 (~/Library/Application Support/Code/User/) を home-manager で
# 管理する。
#
#   * settings.json は repo の tools/vscode/settings.jsonc を読み込み、
#     `${HOME}` plyaceholder を `/Users/${user}` に置換した上で `text =`
#     で in-store 生成する。jsonc コメントは raw string として保持される
#     (programs.vscode の userSettings 経由ではコメントが消える)。
#   * keybindings.json は host 別解決が要らないので out-of-store symlink で
#     repo 内 raw を直接配置。VSCode reload (Cmd+R) で即反映、
#     `nix run .#switch` 不要。
#
# `programs.vscode` (declarative module) は採用しない:
#   * jsonc コメント喪失
#   * 64 個の extension を Nix package に翻訳する調査コスト
#   * `nix-vscode-extensions` flake input を増やすリスク
#   が、`apply-settings.sh` の sed 1 行を `text =` に置換する利得に見合わない。
let
  homePath = "/Users/${user}";
  vscodeDir = "${dotfilesPath}/tools/vscode";
  vscodeUserDir = "Library/Application Support/Code/User";

  # ${HOME} を /Users/${user} に Nix で書き換え。
  # builtins.replaceStrings は raw string 加工なので jsonc コメントは保持される。
  #
  # readFile の引数は **相対 Nix path** にする (絶対パス文字列は pure eval
  # で禁止)。Nix path は flake source tree の Nix store snapshot を指すので、
  # repo を編集したら `nix run .#switch` で再評価して焼き直す必要がある。
  # settings.json は in-store 生成 (text =) なのでこのトレードオフは許容。
  rawSettings = builtins.readFile ../../../tools/vscode/settings.jsonc;
  renderedSettings = builtins.replaceStrings [ "\${HOME}" ] [ homePath ] rawSettings;
in
{
  home.file."${vscodeUserDir}/settings.json".text = renderedSettings;

  # keybindings は out-of-store symlink で raw 配置 (絶対パス文字列で OK、
  # mkOutOfStoreSymlink は eval 時に file 内容を読まないため pure eval 違反
  # にならない)。VSCode reload (Cmd+R) で即反映、`nix run .#switch` 不要。
  home.file."${vscodeUserDir}/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${vscodeDir}/keybindings.jsonc";
}
