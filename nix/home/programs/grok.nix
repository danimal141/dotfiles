{
  lib,
  pkgs,
  hostname,
  ...
}:

# Grok Build CLI を personal ホストだけに導入する。
#
# ~/.grok/config.toml は installer と Grok 自身が更新する mutable な設定なので
# repo から symlink しない。home-manager が管理するのは、Claude Code の hook だけを
# Grok 互換読み込みから外す managed config と、未導入時の installer hook だけにする。
# Claude の instruction / rules / skills / agents / MCP は Grok の Claude 互換機能に
# 任せて再利用する。
lib.mkIf (hostname == "personal") {
  home.file.".grok/managed_config.toml".text = ''
    # Claude Code hooks use Claude-specific stdin and transcript formats.
    [compat.claude]
    hooks = false
  '';

  home.activation.grokInstall = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # Official installer の shell 設定書き換えを防ぐため SHELL を sh に固定し、
    # Homebrew の既存 grok を検出させない。~/.local/bin は PATH に残して、
    # installer がユーザーの shell rc へ PATH ブロックを追記しないようにする。
    (
      export PATH="/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"
      export SHELL=/bin/sh
      export GROK_BIN_DIR="$HOME/.grok/bin"

      GROK_BIN="$HOME/.grok/bin/grok"
      GROK_SHIM="$HOME/.local/bin/grok"

      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$HOME/.local/bin"

      if [ -x "$GROK_BIN" ]; then
        echo "[grokInstall] skip install (already installed at $GROK_BIN)"
      else
        # 既存の通常ファイルは上書きしない。手動導入済みの command を壊さず、
        # canonical path を使いたい場合は通常ファイルを user 側で整理してから再実行する。
        if [ -e "$GROK_SHIM" ] && [ ! -L "$GROK_SHIM" ]; then
          echo "[grokInstall] skip (not overwriting existing file $GROK_SHIM)" >&2
          exit 0
        fi

        CURL_BIN=$(command -v curl || true)
        if [ -z "$CURL_BIN" ]; then
          echo "[grokInstall] skip (curl not found in PATH)" >&2
          exit 0
        fi

        # 社内 VPN SSL inspection 下でも installer を取得できるよう、既存の
        # Claude / APM hook と同じ CA bundle を使う。
        if [ -f /etc/nix/ca-bundle.pem ]; then
          export SSL_CERT_FILE=/etc/nix/ca-bundle.pem
          export CURL_CA_BUNDLE=/etc/nix/ca-bundle.pem
        fi

        echo "[grokInstall] downloading official installer..."
        INSTALLER=$(mktemp)
        if ! "$CURL_BIN" -fsSL https://x.ai/cli/install.sh -o "$INSTALLER"; then
          echo "[grokInstall] FAILED to download installer (will retry next switch)" >&2
          ${pkgs.coreutils}/bin/rm -f "$INSTALLER"
          exit 0
        fi

        # curl | bash は使わず、取得成功を確認してから installer を実行する。
        # GROK_BIN_DIR は official installer の標準配置先を明示する。
        if $DRY_RUN_CMD bash "$INSTALLER"; then
          echo "[grokInstall] installer completed"
        else
          echo "[grokInstall] FAILED (will retry next switch)" >&2
        fi
        ${pkgs.coreutils}/bin/rm -f "$INSTALLER"
      fi

      if [ ! -x "$GROK_BIN" ]; then
        echo "[grokInstall] skip shim (canonical binary not found at $GROK_BIN)" >&2
        exit 0
      fi

      if [ -e "$GROK_SHIM" ] && [ ! -L "$GROK_SHIM" ]; then
        echo "[grokInstall] skip shim (not overwriting existing file $GROK_SHIM)" >&2
        exit 0
      fi

      # zshrc を編集せず、既存 PATH に合わせて command を見つけられる shim を作る。
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -sfn "$GROK_BIN" "$GROK_SHIM"
      echo "[grokInstall] available at $GROK_SHIM"
    )
  '';
}
