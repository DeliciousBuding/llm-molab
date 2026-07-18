#!/usr/bin/env bash
# Run cloudflared from package path /marimo/bin first.
set -euo pipefail

LAB="${LLM_LAB:-/marimo/llm-lab}"
if [[ -f "$LAB/state/serve.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$LAB/state/serve.env"; set +a
fi

TOKEN_FILE="${TUNNEL_TOKEN_FILE:-/tmp/.secrets/tunnel.token}"
LOG="$LAB/logs/cloudflared.log"
PIDF="$LAB/logs/cloudflared.pid"
HOSTNAME="${TUNNEL_HOSTNAME:-llm.vectorcontrol.tech}"
LOCAL_URL="http://${SERVE_HOST:-127.0.0.1}:${SERVE_PORT:-8000}"

mkdir -p "$LAB/logs" /marimo/bin

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "missing $TOKEN_FILE" >&2
  exit 1
fi

# package-first binary
if [[ -x /marimo/bin/cloudflared ]]; then
  CFBIN=/marimo/bin/cloudflared
elif [[ -x "$LAB/cf/cloudflared" ]]; then
  CFBIN="$LAB/cf/cloudflared"
elif command -v cloudflared >/dev/null 2>&1; then
  CFBIN="$(command -v cloudflared)"
else
  bash /marimo/work/llm-molab/scripts/13_ensure_cloudflared.sh
  CFBIN=/marimo/bin/cloudflared
fi

if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "cloudflared already running pid=$(cat "$PIDF")"
  exit 0
fi
pkill -f 'cloudflared tunnel' 2>/dev/null || true

TOKEN="$(tr -d '\r\n' <"$TOKEN_FILE")"
nohup "$CFBIN" tunnel --no-autoupdate run --token "$TOKEN" >"$LOG" 2>&1 &
echo $! >"$PIDF"
echo "cloudflared pid=$(cat "$PIDF") bin=$CFBIN hostname=$HOSTNAME local=$LOCAL_URL"
date -u +%Y-%m-%dT%H:%M:%SZ >"$LAB/state/last_tunnel_at"
