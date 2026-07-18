#!/usr/bin/env bash
# Wait until OpenAI /v1/models responds.
set -euo pipefail

if [[ -f /tmp/.secrets/llm.env ]]; then
  # shellcheck disable=SC1091
  set -a; source /tmp/.secrets/llm.env; set +a
fi

: "${LLM_API_KEY:?need LLM_API_KEY}"
BASE="${OPENAI_BASE_URL:-http://127.0.0.1:8000/v1}"
TIMEOUT="${WAIT_TIMEOUT_S:-900}"
t0=$(date +%s)

while true; do
  now=$(date +%s)
  if (( now - t0 > TIMEOUT )); then
    echo "timeout after ${TIMEOUT}s" >&2
    tail -n 80 /marimo/llm-lab/logs/sglang-api.log 2>/dev/null || true
    tail -n 80 /marimo/llm-lab/logs/sglang-prod.log 2>/dev/null || true
    tail -n 80 /marimo/llm-lab/logs/sglang-baseline.log 2>/dev/null || true
    exit 1
  fi
  if curl -fsS "$BASE/models" -H "Authorization: Bearer $LLM_API_KEY" >/tmp/models.json 2>/dev/null; then
    echo "api_ready"
    head -c 500 /tmp/models.json; echo
    exit 0
  fi
  echo "waiting... $((now - t0))s"
  sleep 10
done
