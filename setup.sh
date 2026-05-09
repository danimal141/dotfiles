#!/bin/bash
# 新規 Mac の bootstrap スクリプト。
#
# 使い方:
#   ./setup.sh             — LocalHostName を見て自動判定 (work / personal / personal2 ...)
#   ./setup.sh work        — 仕事用 Mac 想定で flake host を明示
#   ./setup.sh personal    — 個人用 Mac
#
# 完走する処理 (上から順):
#   1. Xcode CLT (Apple Silicon 専用想定、Rosetta は使わない)
#   2. Nix (公式 upstream installer) を入れて、現在の shell でも nix を使えるようにする
#   3. 社内 VPN の SSL inspection 対策 — macOS Keychain から CA bundle を作って
#      nix-daemon にも渡す
#   4. nix-darwin が /etc/* を引き取る前段階として、Nix インストーラ由来の
#      /etc/bashrc / /etc/nix/nix.conf を *.before-nix-darwin に退避
#   5. `darwin-rebuild switch` で nix/darwin/{defaults,keyboard,nix-daemon,
#      system,packages,homebrew}.nix を一括反映 (sudo 必須、experimental-features
#      は CLI フラグで渡す)
#   6. home-manager (nix-darwin に統合) が ~/ 配下の dotfile を symlink 配置
#      mise CLI と global config (~/.config/mise/config.toml) もこの段で配置される
#   7. mise install で ~/.config/mise/config.toml の言語 binary を実体 install
#   8. LSP / VSCode 拡張のセットアップ
set -e

# ---- Hostname target -------------------------------------------------------
# LocalHostName が flake の hosts attrset (work / personal / personal2 ...) と
# 一致する場合は自動で flake host を決定する。一致しない時 (= 新規 Mac で IT
# 部門が払い出した hostname のままの状態) は、第一引数で明示できる。
DETECTED="$(scutil --get LocalHostName 2>/dev/null || echo)"
TARGET_HOST="${1:-$DETECTED}"
case "$TARGET_HOST" in
  work|personal|personal[0-9]*) ;;
  *)
    echo "[setup] LocalHostName '$DETECTED' is not a known flake host."
    echo "[setup] Defaulting to 'work'. Override with: ./setup.sh <hostname>"
    TARGET_HOST="work"
    ;;
esac
echo "[setup] Targeting flake host: .#$TARGET_HOST"

# ---- Xcode CLT ------------------------------------------------------------
# Apple Silicon 前提なので Rosetta は install しない。x86_64 binary が必要に
# なったら手動で `softwareupdate --install-rosetta` する想定。
echo "[setup] Installing Xcode CLT..."
xcode-select --install 2>/dev/null || true

# ---- Nix install ----------------------------------------------------------
# `https://nixos.org/nix/install` が公式 upstream マルチユーザ installer。
# 末尾を `installer` と書くと 404 になるので注意。
if ! command -v nix >/dev/null 2>&1; then
  echo "[setup] Installing Nix (official upstream installer)..."
  sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
fi

# Nix インストーラ直後は現在の shell に nix が居ないので profile を source する。
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# ---- Corporate VPN SSL inspection support ---------------------------------
# nix-daemon は launchd 経由で root 起動するため、ユーザー shell の
# NIX_SSL_CERT_FILE 環境変数を読まない。社内 VPN が SSL inspection (中間者 CA)
# を挟む環境では、nixpkgs / github.com への fetch がそのままだと self-signed
# certificate エラーで止まる。
#
# macOS Keychain (System + System Roots) を 1 ファイルに焼き出して daemon に
# launchctl setenv で渡す。社内 CA を Keychain に push してくれている前提。
# 個人 Mac (中間者 CA 無し) でも害はない (= 普通のシステム CA 束ができるだけ)。
#
# nix-darwin の switch が完走すると `nix.settings.ssl-cert-file` (flake 宣言)
# が /etc/nix/nix.conf に書き込まれるので、以降は nix.conf 経由で完結する。
CA_BUNDLE=/etc/nix/ca-bundle.pem
if [ ! -s "$CA_BUNDLE" ]; then
  echo "[setup] Generating $CA_BUNDLE from macOS Keychain..."
  sudo bash -c "
    install -m 0644 /dev/null '$CA_BUNDLE'
    security find-certificate -a -p /Library/Keychains/System.keychain >> '$CA_BUNDLE'
    security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain >> '$CA_BUNDLE'
  "
fi
echo "[setup] Pointing nix-daemon at $CA_BUNDLE"
sudo launchctl setenv NIX_SSL_CERT_FILE "$CA_BUNDLE"
sudo launchctl kickstart -k system/org.nixos.nix-daemon || true
# 同 shell の nix CLI も同じ bundle を見るようにしておく
export NIX_SSL_CERT_FILE="$CA_BUNDLE"

# ---- Move conflicting /etc files out of the way ---------------------------
# nix-darwin は activation 時に /etc/* を生成するが、Nix 公式 installer が
# 前段で書いた /etc/bashrc (4 行追記) と /etc/nix/nix.conf (build-users-group
# 1 行) は「unrecognized content」と見なされて activation を abort する。
# 既に *.before-nix-darwin が在れば再退避しない (= 二度目の setup.sh は no-op)。
for f in /etc/bashrc /etc/nix/nix.conf; do
  if [ -f "$f" ] && [ ! -f "$f.before-nix-darwin" ]; then
    # nix-darwin 生成済みファイルかどうかを簡易判定 (header に nix-darwin の
    # 文字列が入る)。既に generated 状態なら退避不要。
    if ! sudo head -3 "$f" 2>/dev/null | grep -qE "nix-darwin|nix\.\* options"; then
      echo "[setup] Renaming $f -> $f.before-nix-darwin"
      sudo mv "$f" "$f.before-nix-darwin"
    fi
  fi
done

# ---- Apply nix-darwin ------------------------------------------------------
# 注意点:
#   * nix-darwin >= 25.05 は activation を root 権限で要求する → sudo 必須。
#   * sudo 配下では root の Nix 設定 (= /etc/nix/nix.conf) を読みに行くが、
#     上で nix.conf を退避済みなので experimental-features は CLI フラグで渡す。
#   * `-E` で PATH と NIX_SSL_CERT_FILE を sudo に引き継ぐ。Nix の絶対パスを
#     使う方法でも良いが、`-E` の方がシンプル。
echo "[setup] Applying nix-darwin (Nix store CLI / Homebrew / macOS settings) for .#$TARGET_HOST..."
sudo -E nix --extra-experimental-features 'nix-command flakes' \
  run nix-darwin -- switch --flake ".#$TARGET_HOST"

# ---- mise / language runtimes ---------------------------------------------
# `~/.config/mise/config.toml` (home-manager 経由で repo の mise/config.toml
# を symlink 配置済み) に宣言された言語ランタイムを mise でまとめて install
# する。mise CLI 自体は darwin-rebuild で home-manager profile に入った
# 状態で、ここでは各言語の実体 binary を pull する。失敗しても止めないのは、
# 一部のビルド失敗で全体を中断するより後段 (LSP / VSCode 等) を最後まで
# 流す方が後で個別にやり直しやすいため。
echo "[setup] Installing language runtimes from ~/.config/mise/config.toml via mise..."
mise install || true

# LSP server は npm/gem/go が走る言語でだけ事前 install しておく。
# `mise reshim` は npm install -g などで作った shim を再生成して PATH に
# 反映するために必要 (mise 経由の node なら自動だが、global install 直後は明示)。
echo "[setup] Installing LSP servers..."
npm install -g typescript-language-server typescript || true
npm install -g pyright || true
gem install ruby-lsp --no-doc || true
go install golang.org/x/tools/gopls@latest || true
mise reshim || true

# ---- VSCode ---------------------------------------------------------------
echo "[setup] Setting up VSCode..."
if [ -f ./vscode/apply-settings.sh ]; then
  ./vscode/apply-settings.sh
fi
if [ -f ./vscode/sync-extensions.sh ]; then
  ./vscode/sync-extensions.sh --install
fi

# ---- secretlint deps + pre-commit hook (prek) ------------------------------
# secretlint 本体と rule preset (`@secretlint/secretlint-rule-preset-recommend`)
# を `package-lock.json` から再現性高く install する。`npx -y` 隔離環境では
# `.secretlintrc.json` が要求する rule package を解決できず hook が落ちるため、
# ローカル `node_modules/` に固定して `npx secretlint` 経由で参照させる。
if [ -f ./package-lock.json ] && command -v npm >/dev/null 2>&1; then
  echo "[setup] Installing secretlint dependencies via npm ci..."
  npm ci || true
fi

# `.pre-commit-config.yaml` の secretlint hook を git hooks に登録する。
# prek は pre-commit の Rust 実装、`nix/darwin/packages.nix` で配布済 (= ここでは
# 既に PATH にあること前提)。`prek install` は冪等 (`.git/hooks/pre-commit`
# を上書き) なので二度目の setup.sh でも問題ない。
if [ -f ./.pre-commit-config.yaml ] && command -v prek >/dev/null 2>&1; then
  echo "[setup] Installing prek hooks (.git/hooks/pre-commit)..."
  prek install
fi

# 新 shell を起動して PATH と home-manager symlink 配置を反映する。
exec $SHELL -l
