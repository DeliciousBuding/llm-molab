#!/usr/bin/env bash
# Wait until OpenAI /v1/models responds.
set -euo pipefail

LAB="${LLM_LAB:-/marimo/llm-lab}"
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
: "${LLM_API_KEY:?need LLM_API_KEY}"
BASE="${OPENAI_BASE_URL:-http://${HOST}:${PORT}/v1}"
TIMEOUT="${WAIT_TIMEOUT_S:-1200}"
t0=$(date +%s)

while true; do
  now=$(date +%s)
  if (( now - t0 > TIMEOUT )); then
    echo "timeout after ${TIMEOUT}s" >&2
    tail -n 120 "$LAB/logs/vllm-api.log" 2>/dev/null || true
    tail -n 80 "$LAB/logs/sglang-api.log" 2>/dev/null || true
    exit 1
  fi
  if curl -fsS "$BASE/models" -H "Authorization: Bearer $LLM_API_KEY" >/tmp/models.json 2>/dev/null; then
    echo "api_ready base=$BASE"
    head -c 800 /tmp/models.json; echo
    exit 0
  fi
  if (( (now - t0) % 30 < 10 )); then
    echo "waiting... $((now - t0))s"
    tail -n 8 "$LAB/logs/vllm-api.log" 2>/dev/null || true
    tail -n 5 "$LAB/logs/sglang-api.log" 2>/dev/null || true
  fi
  sleep 10
done
