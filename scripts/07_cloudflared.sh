#!/usr/bin/env bash
# Run cloudflared named tunnel (token) -> local SGLang.
# Token is runtime-only; DNS/tunnel UUID are durable on Cloudflare side.
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

mkdir -p "$LAB/logs" "$LAB/cf"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "missing $TOKEN_FILE (re-inject after restart)" >&2
  exit 1
fi

CFBIN="$(command -v cloudflared || true)"
if [[ -z "$CFBIN" ]]; then
  echo "installing cloudflared to $LAB/cf (durable)"
  curl -fsSL -o "$LAB/cf/cloudflared" \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  chmod +x "$LAB/cf/cloudflared"
  CFBIN="$LAB/cf/cloudflared"
fi

if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "cloudflared already running pid=$(cat "$PIDF")"
  exit 0
fi
pkill -f 'cloudflared tunnel' 2>/dev/null || true

TOKEN="$(tr -d '\r\n' <"$TOKEN_FILE")"
nohup "$CFBIN" tunnel --no-autoupdate run --token "$TOKEN" >"$LOG" 2>&1 &
echo $! >"$PIDF"
echo "cloudflared pid=$(cat "$PIDF") hostname=$HOSTNAME local=$LOCAL_URL log=$LOG"
date -u +%Y-%m-%dT%H:%M:%SZ >"$LAB/state/last_tunnel_at"
