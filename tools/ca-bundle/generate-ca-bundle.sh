#!/bin/bash
# macOS Keychain (System + System Roots) から CA bundle を焼き出す。
# 社内 CA (Netskope 等) は System.keychain に push されている前提。
#
#   sudo tools/ca-bundle/generate-ca-bundle.sh [出力先 (既定: /etc/nix/ca-bundle.pem)]
#
# Keychain は「信頼しない」設定を PEM に持ち出せないため、Mozilla (certifi) が
# 信頼を外したルートを DISTRUSTED で明示的に除外する。
#   * emSign ECC Root CA - G3: eMudhra 中間 CA の鍵問題 (2026-10、certifi 2026.10.19 で除外)
#   * AAA Certificate Services: 同じ中間 CA を相互署名している。Mozilla は TLS 用に信頼していない
set -euo pipefail

OUT=${1:-/etc/nix/ca-bundle.pem}
DISTRUSTED=(
  "emSign ECC Root CA - G3"
  "AAA Certificate Services"
)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

security find-certificate -a -p /Library/Keychains/System.keychain >"$tmp/all.pem"
security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain >>"$tmp/all.pem"

# 1 証明書 1 ファイルに分ける
awk -v dir="$tmp" '/BEGIN CERTIFICATE/ { n++ } n { print > (dir "/cert-" n ".pem") }' "$tmp/all.pem"

: >"$tmp/bundle.pem"
for cert in "$tmp"/cert-*.pem; do
  subject=$(openssl x509 -noout -subject -in "$cert")
  skip=
  for name in "${DISTRUSTED[@]}"; do
    if grep -qE "CN ?= ?$name(,|$)" <<<"$subject"; then
      skip=1
      echo "[ca-bundle] excluded: $name" >&2
    fi
  done
  [ -n "$skip" ] || cat "$cert" >>"$tmp/bundle.pem"
done

install -m 0644 "$tmp/bundle.pem" "$OUT"
echo "[ca-bundle] wrote $OUT ($(grep -c 'BEGIN CERTIFICATE' "$OUT") certs)" >&2
