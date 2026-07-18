#!/usr/bin/env bash
# Phase 0 baseline: 32K, no MTP.
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
LOG="$ROOT/logs/sglang-baseline.log"
PIDF="$ROOT/logs/sglang.pid"

# shellcheck disable=SC1091
source "$ROOT/.venv-sglang/bin/activate"

mkdir -p "$ROOT/logs"
if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "already running pid=$(cat "$PIDF")" >&2
  exit 0
fi

nohup python -m sglang.launch_server \
  --model-path "$MODEL_PATH" \
  --host "$HOST" \
  --port "$PORT" \
  --context-length 32768 \
  --mem-fraction-static 0.80 \
  --reasoning-parser qwen3 \
  --tool-call-parser qwen3_coder \
  --api-key "$LLM_API_KEY" \
  >"$LOG" 2>&1 &

echo $! >"$PIDF"
echo "started pid=$(cat "$PIDF") log=$LOG"
echo "wait for /v1/models then smoke with scripts/08_smoke.sh"
