#!/usr/bin/env bash
# Run cloudflared named tunnel (token) -> local SGLang.
set -euo pipefail

ROOT="${LLM_LAB:-/marimo/llm-lab}"
TOKEN_FILE="${TUNNEL_TOKEN_FILE:-/tmp/.secrets/tunnel.token}"
LOG="$ROOT/logs/cloudflared.log"
PIDF="$ROOT/logs/cloudflared.pid"
HOSTNAME="${TUNNEL_HOSTNAME:-llm.vectorcontrol.tech}"
LOCAL_URL="${LOCAL_URL:-http://127.0.0.1:8000}"

mkdir -p "$ROOT/logs" "$ROOT/cf"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "missing $TOKEN_FILE" >&2
  exit 1
fi

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "installing cloudflared..."
  curl -fsSL -o /tmp/cloudflared \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  chmod +x /tmp/cloudflared
  sudo mv /tmp/cloudflared /usr/local/bin/cloudflared 2>/dev/null || mv /tmp/cloudflared "$ROOT/cf/cloudflared"
  export PATH="$ROOT/cf:$PATH"
fi

if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "cloudflared already running pid=$(cat "$PIDF")"
  exit 0
fi

TOKEN="$(tr -d '\r\n' <"$TOKEN_FILE")"

# Token-managed tunnel: ingress is bound in Cloudflare Zero Trust dashboard
# OR use quick override with --url for local-only named? Prefer config if present.
CFG="$ROOT/cf/config.yml"
if [[ -f "$CFG" ]]; then
  nohup cloudflared tunnel --config "$CFG" run >"$LOG" 2>&1 &
else
  # Named tunnel via token; route hostname in CF DNS already points at tunnel UUID.
  nohup cloudflared tunnel --no-autoupdate run --token "$TOKEN" >"$LOG" 2>&1 &
fi

echo $! >"$PIDF"
echo "cloudflared pid=$(cat "$PIDF") hostname=$HOSTNAME local=$LOCAL_URL log=$LOG"
echo "NOTE: for token tunnels, configure Public Hostname in CF Zero Trust to $HOSTNAME -> $LOCAL_URL if not using credentials config."
