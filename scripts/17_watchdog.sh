#!/usr/bin/env bash
# Watchdog: keep vLLM API + cloudflared up on a live sandbox (same sb, no remint).
# usage:
#   bash scripts/17_watchdog.sh once     # single check/fix
#   bash scripts/17_watchdog.sh loop 60  # every 60s
set -euo pipefail

MODE="${1:-once}"
INTERVAL="${2:-60}"
REPO="${REPO_DIR:-/marimo/work/llm-molab}"
LAB="${LLM_LAB:-/marimo/llm-lab}"
LOG="$LAB/logs/watchdog.log"
mkdir -p "$LAB/logs"

if [[ -f "$LAB/state/serve.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$LAB/state/serve.env"; set +a
fi
if [[ -f /tmp/.secrets/llm.env ]]; then
  # shellcheck disable=SC1091
  set -a; source /tmp/.secrets/llm.env; set +a
fi

strip() { printf '%s' "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }
LLM_API_KEY="$(strip "${LLM_API_KEY:-}")"
HOST="$(strip "${SERVE_HOST:-127.0.0.1}")"
PORT="$(strip "${SERVE_PORT:-8000}")"
BASE="http://${HOST}:${PORT}/v1"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

check_api() {
  [[ -n "$LLM_API_KEY" ]] || return 1
  curl -fsS -m 5 "$BASE/models" -H "Authorization: Bearer $LLM_API_KEY" >/dev/null 2>&1
}

check_cf() {
  pgrep -f 'cloudflared tunnel' >/dev/null 2>&1
}

fix_once() {
  local api_ok=0 cf_ok=0
  if check_api; then api_ok=1; else api_ok=0; fi
  if check_cf; then cf_ok=1; else cf_ok=0; fi
  echo "$(ts) api=$api_ok cloudflared=$cf_ok" | tee -a "$LOG"

  if [[ "$api_ok" -eq 0 ]]; then
    echo "$(ts) action=restart_vllm" | tee -a "$LOG"
    if [[ -x "$REPO/scripts/05b_serve_vllm.sh" ]]; then
      bash "$REPO/scripts/05b_serve_vllm.sh" || true
      bash "$REPO/scripts/10_wait_api.sh" || true
    fi
  fi

  if [[ "$cf_ok" -eq 0 ]]; then
    echo "$(ts) action=restart_cloudflared" | tee -a "$LOG"
    if [[ -x "$REPO/scripts/07_cloudflared.sh" ]]; then
      bash "$REPO/scripts/07_cloudflared.sh" || true
    fi
  fi
}

case "$MODE" in
  once)
    fix_once
    ;;
  loop)
    while true; do
      fix_once || true
      sleep "$INTERVAL"
    done
    ;;
  *)
    echo "usage: $0 once|loop [interval_s]" >&2
    exit 2
    ;;
esac
