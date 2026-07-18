#!/usr/bin/env bash
# Production candidate: 128K + MTP + FP8 KV (verify with A/B first).
set -euo pipefail

if [[ -f /tmp/.secrets/llm.env ]]; then
  # shellcheck disable=SC1091
  set -a; source /tmp/.secrets/llm.env; set +a
fi

: "${LLM_API_KEY:?set LLM_API_KEY in /tmp/.secrets/llm.env}"
MODEL_PATH="${MODEL_PATH:-/marimo/models/Qwen3.6-35B-A3B-FP8}"
HOST="${SERVE_HOST:-127.0.0.1}"
PORT="${SERVE_PORT:-8000}"
ROOT="${LLM_LAB:-/marimo/llm-lab}"
LOG="$ROOT/logs/sglang-prod.log"
PIDF="$ROOT/logs/sglang.pid"

# shellcheck disable=SC1091
source "$ROOT/.venv-sglang/bin/activate"

mkdir -p "$ROOT/logs"
if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "stopping old pid=$(cat "$PIDF")"
  kill "$(cat "$PIDF")" 2>/dev/null || true
  sleep 3
fi

nohup python -m sglang.launch_server \
  --model-path "$MODEL_PATH" \
  --host "$HOST" \
  --port "$PORT" \
  --context-length 131072 \
  --mem-fraction-static 0.88 \
  --kv-cache-dtype fp8_e4m3 \
  --chunked-prefill-size 8192 \
  --reasoning-parser qwen3 \
  --tool-call-parser qwen3_coder \
  --speculative-algo NEXTN \
  --speculative-num-steps 3 \
  --speculative-eagle-topk 1 \
  --speculative-num-draft-tokens 4 \
  --api-key "$LLM_API_KEY" \
  >"$LOG" 2>&1 &

echo $! >"$PIDF"
echo "started pid=$(cat "$PIDF") log=$LOG"
