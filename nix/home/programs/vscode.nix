{ config, lib, pkgs, user, dotfilesPath, ... }:

# VSCode 設定 (~/Library/Application Support/Code/User/) を home-manager で
# 管理する。
#
#   * settings.json は repo の tools/vscode/settings.jsonc を読み込み、
#     `${HOME}` placeholder を `/Users/${user}` に置換した上で `text =`
#     で in-store 生成する。jsonc コメントは raw string として保持される
#     (programs.vscode の userSettings 経由ではコメントが消える)。
#   * keybindings.json は host 別解決が要らないので out-of-store symlink で
#     repo 内 raw を直接配置。VSCode reload (Cmd+R) で即反映、
#     `nix run .#switch` 不要。
#   * extensions は repo の tools/vscode/extensions.txt を 1 行ずつ走査し、
#     `code --list-extensions` 差分のみ `code --install-extension` する
#     冪等 hook。`code` が PATH に居ない環境では skip して switch 全体は
#     止めない (apm.nix と同パターン)。
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

  # extensions install hook。`entryAfter ["linkGeneration"]` を使う理由:
  # writeBoundary 直後に走らせると、後続の linkGeneration がまだ動いて
  # おらず、過去世代から残っている broken symlink (path リネーム直後等)
  # を踏んで activation 全体が abort する。実際 tools/ refactor で apm
  # の hook がこの罠を踏んだ前例あり (memory: feedback_home_manager_
  # activation_order.md)。VSCode hook は extensions.txt を repo 直読み
  # するため linkGeneration に依存しないが、pattern 統一のため
  # linkGeneration 後を選ぶ。
  home.activation.vscodeExtensions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # `code` shim は VSCode cask が brew prefix に置く。home-manager
    # activation の default PATH には居ないので明示的に append する。
    export PATH="/run/current-system/sw/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

    # 社内 VPN の SSL inspection (中間者 CA) 対策。VSCode は Electron 上で
    # Node の TLS スタックを使うため、システム CA bundle を NODE_EXTRA_CA_CERTS
    # で明示的に渡さないと marketplace への HTTPS で self-signed cert エラー。
    # /etc/nix/ca-bundle.pem は setup.sh が macOS Keychain から焼く CA bundle
    # で、社内 CA を含む。個人 Mac では同 file が存在しても無害 (普通のシステム
    # CA 束)。bundle が無い環境では未設定のまま (= Node 既定の CA で動作)。
    if [ -f /etc/nix/ca-bundle.pem ]; then
      export NODE_EXTRA_CA_CERTS=/etc/nix/ca-bundle.pem
    fi

    CODE_BIN=$(command -v code || true)
    if [ -z "$CODE_BIN" ]; then
      echo "[vscodeExtensions] skip: 'code' not in PATH (VSCode not installed?)"
      exit 0
    fi

    EXT_FILE="${vscodeDir}/extensions.txt"
    if [ ! -f "$EXT_FILE" ]; then
      echo "[vscodeExtensions] skip: $EXT_FILE not found"
      exit 0
    fi

    # 現在 install 済みの拡張一覧を 1 回だけ取得 (ループ毎に code を呼ばない)。
    INSTALLED=$("$CODE_BIN" --list-extensions 2>/dev/null || echo "")

    while IFS= read -r ext || [ -n "$ext" ]; do
      [ -z "$ext" ] && continue
      case "$ext" in \#*) continue ;; esac
      if ! echo "$INSTALLED" | ${pkgs.gnugrep}/bin/grep -qix "$ext"; then
        echo "[vscodeExtensions] installing $ext"
        $DRY_RUN_CMD "$CODE_BIN" --install-extension "$ext" --force >/dev/null 2>&1 \
          || echo "[vscodeExtensions] FAILED $ext"
      fi
    done < "$EXT_FILE"
  '';
}
