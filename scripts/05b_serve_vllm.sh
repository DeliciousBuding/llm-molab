#!/usr/bin/env bash
# Serve with vLLM (OpenAI-compatible). Strips whitespace from env values.
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

# strip CR/whitespace that Windows env files sometimes leave
strip() { printf '%s' "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }
LLM_API_KEY="$(strip "${LLM_API_KEY:-}")"
MODEL_PATH="$(strip "${MODEL_PATH:-/marimo/models/Qwen3.6-35B-A3B-FP8}")"
HOST="$(strip "${SERVE_HOST:-127.0.0.1}")"
PORT="$(strip "${SERVE_PORT:-8000}")"
CTX="$(strip "${CONTEXT_LENGTH:-131072}")"
MEM="$(strip "${MEM_FRACTION_STATIC:-0.88}")"

: "${LLM_API_KEY:?set LLM_API_KEY}"
[[ -f "$MODEL_PATH/config.json" ]] || { echo "missing model at $MODEL_PATH" >&2; exit 1; }

LOG="$LAB/logs/vllm-api.log"
PIDF="$LAB/logs/sglang.pid"

# shellcheck disable=SC1091
source "$LAB/.venv-vllm/bin/activate"
mkdir -p "$LAB/logs"

# kill anything stale
if [[ -f "$PIDF" ]]; then
  old="$(cat "$PIDF" || true)"
  if [[ -n "$old" ]]; then kill "$old" 2>/dev/null || true; fi
  rm -f "$PIDF"
fi
pkill -f 'vllm.entrypoints' 2>/dev/null || true
pkill -f 'sglang.launch_server' 2>/dev/null || true
sleep 2

echo "starting vllm model=$MODEL_PATH host=$HOST port=$PORT ctx=$CTX mem=$MEM"
# Prefer modern CLI if present
if command -v vllm >/dev/null 2>&1; then
  nohup vllm serve "$MODEL_PATH" \
    --host "$HOST" \
    --port "$PORT" \
    --api-key "$LLM_API_KEY" \
    --max-model-len "$CTX" \
    --gpu-memory-utilization "$MEM" \
    --enable-prefix-caching \
    --trust-remote-code \
    >"$LOG" 2>&1 &
else
  nohup python -m vllm.entrypoints.openai.api_server \
    --model "$MODEL_PATH" \
    --host "$HOST" \
    --port "$PORT" \
    --api-key "$LLM_API_KEY" \
    --max-model-len "$CTX" \
    --gpu-memory-utilization "$MEM" \
    --enable-prefix-caching \
    --trust-remote-code \
    >"$LOG" 2>&1 &
fi

echo $! >"$PIDF"
echo "vllm_started pid=$(cat "$PIDF") log=$LOG"
echo "vllm" >"$LAB/state/last_serve_mode"
date -u +%Y-%m-%dT%H:%M:%SZ >"$LAB/state/last_serve_at"
