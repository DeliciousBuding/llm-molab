#!/usr/bin/env bash
# Serve with vLLM (OpenAI-compatible) as SGLang fallback.
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

: "${LLM_API_KEY:?set LLM_API_KEY}"
MODEL_PATH="${MODEL_PATH:-/marimo/models/Qwen3.6-35B-A3B-FP8}"
HOST="${SERVE_HOST:-127.0.0.1}"
PORT="${SERVE_PORT:-8000}"
LOG="$LAB/logs/vllm-api.log"
PIDF="$LAB/logs/sglang.pid"   # shared stop path with 09_stop_local

# shellcheck disable=SC1091
source "$LAB/.venv-vllm/bin/activate"
mkdir -p "$LAB/logs"

if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "already_running pid=$(cat "$PIDF")"
  exit 0
fi
pkill -f 'sglang.launch_server' 2>/dev/null || true
pkill -f 'vllm.entrypoints' 2>/dev/null || true
pkill -f 'VLLM::' 2>/dev/null || true
sleep 1

nohup python -m vllm.entrypoints.openai.api_server \
  --model "$MODEL_PATH" \
  --host "$HOST" \
  --port "$PORT" \
  --api-key "$LLM_API_KEY" \
  --max-model-len "${CONTEXT_LENGTH:-131072}" \
  --gpu-memory-utilization "${MEM_FRACTION_STATIC:-0.88}" \
  --enable-prefix-caching \
  --reasoning-parser qwen3 \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder \
  >"$LOG" 2>&1 &

echo $! >"$PIDF"
echo "vllm_started pid=$(cat "$PIDF") log=$LOG"
echo "vllm" >"$LAB/state/last_serve_mode"
date -u +%Y-%m-%dT%H:%M:%SZ >"$LAB/state/last_serve_at"
