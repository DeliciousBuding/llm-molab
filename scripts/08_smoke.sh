#!/usr/bin/env bash
# Local smoke against OpenAI-compatible endpoint.
set -euo pipefail

if [[ -f /tmp/.secrets/llm.env ]]; then
  # shellcheck disable=SC1091
  set -a; source /tmp/.secrets/llm.env; set +a
fi

: "${LLM_API_KEY:?need LLM_API_KEY}"
BASE="${OPENAI_BASE_URL:-http://127.0.0.1:8000/v1}"

echo "== models =="
curl -fsS "$BASE/models" -H "Authorization: Bearer $LLM_API_KEY" | head -c 2000
echo

echo "== chat =="
curl -fsS "$BASE/chat/completions" \
  -H "Authorization: Bearer $LLM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "default",
    "messages": [{"role":"user","content":"Reply with exactly: pong"}],
    "max_tokens": 32,
    "temperature": 0
  }' | head -c 2000
echo
echo "smoke_ok"
