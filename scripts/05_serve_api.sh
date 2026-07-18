#!/usr/bin/env bash
# Start SGLang OpenAI-compatible API (prod candidate defaults).
# Falls back to lighter flags if aggressive ones fail on first boot.
set -euo pipefail

if [[ -f /tmp/.secrets/llm.env ]]; then
  # shellcheck disable=SC1091
  set -a; source /tmp/.secrets/llm.env; set +a
fi

: "${LLM_API_KEY:?set LLM_API_KEY in /tmp/.secrets/llm.env}"
MODEL_PATH="${MODEL_PATH:-/marimo/models/Qwen3.6-35B-A3B-FP8}"
HOST="${SERVE_HOST:-127.0.0.1}"
PORT="${SERVE_PORT:-8000}"
ROOT="/marimo/llm-lab"
LOG="$ROOT/logs/sglang-api.log"
PIDF="$ROOT/logs/sglang.pid"
MODE="${SERVE_MODE:-prod}"   # baseline | prod

# shellcheck disable=SC1091
source "$ROOT/.venv-sglang/bin/activate"
mkdir -p "$ROOT/logs"

if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "already_running pid=$(cat "$PIDF")"
  exit 0
fi
# stale pid
rm -f "$PIDF"
pkill -f 'sglang.launch_server' 2>/dev/null || true
sleep 1

COMMON=(
  --model-path "$MODEL_PATH"
  --host "$HOST"
  --port "$PORT"
  --reasoning-parser qwen3
  --tool-call-parser qwen3_coder
  --api-key "$LLM_API_KEY"
)

if [[ "$MODE" == "baseline" ]]; then
  ARGS=(
    "${COMMON[@]}"
    --context-length 32768
    --mem-fraction-static 0.80
  )
else
  ARGS=(
    "${COMMON[@]}"
    --context-length 131072
    --mem-fraction-static 0.88
    --kv-cache-dtype fp8_e4m3
    --chunked-prefill-size 8192
    --speculative-algo NEXTN
    --speculative-num-steps 3
    --speculative-eagle-topk 1
    --speculative-num-draft-tokens 4
  )
fi

echo "starting mode=$MODE log=$LOG"
nohup python -m sglang.launch_server "${ARGS[@]}" >"$LOG" 2>&1 &
echo $! >"$PIDF"
echo "started pid=$(cat "$PIDF")"
