#!/usr/bin/env bash
# Ensure cloudflared at /marimo/bin (package path).
set -euo pipefail

BIN_DIR="${BIN_DIR:-/marimo/bin}"
TARGET="$BIN_DIR/cloudflared"
LEGACY="/marimo/llm-lab/cf/cloudflared"
mkdir -p "$BIN_DIR"

if [[ -x "$TARGET" ]]; then
  echo "cloudflared_ok $TARGET"
  exit 0
fi
if [[ -x "$LEGACY" ]]; then
  cp -f "$LEGACY" "$TARGET" && chmod +x "$TARGET"
  echo "cloudflared_promoted $TARGET"
  exit 0
fi

echo "installing cloudflared -> $TARGET (package tree)"
curl -fsSL -o "$TARGET" \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x "$TARGET"
echo "cloudflared_installed $TARGET"
