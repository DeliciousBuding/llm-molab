#!/usr/bin/env bash
# Serve with vLLM (OpenAI-compatible). Strips whitespace from env values.
# Reads /marimo/llm-lab/state/serve.env (profile via scripts/16_apply_profile.sh).
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
CTX="$(strip "${CONTEXT_LENGTH:-32768}")"
MEM="$(strip "${MEM_FRACTION_STATIC:-0.80}")"
KV="$(strip "${KV_CACHE_DTYPE:-}")"
MAX_SEQS="$(strip "${MAX_NUM_SEQS:-}")"
PREFIX="$(strip "${ENABLE_PREFIX_CACHING:-1}")"
SERVED_NAME="$(strip "${SERVED_MODEL_NAME:-Qwen3.6-35B-A3B-FP8}")"
MODE="$(strip "${SERVE_MODE:-baseline}")"

: "${LLM_API_KEY:?set LLM_API_KEY}"
[[ -f "$MODEL_PATH/config.json" ]] || { echo "missing model at $MODEL_PATH" >&2; exit 1; }

LOG="$LAB/logs/vllm-api.log"
PIDF="$LAB/logs/sglang.pid"

# Prefer env file over process argv for key when possible — still need CLI for vLLM.
# shellcheck disable=SC1091
source "$LAB/.venv-vllm/bin/activate"
mkdir -p "$LAB/logs"

if [[ -f "$PIDF" ]]; then
  old="$(cat "$PIDF" || true)"
  if [[ -n "$old" ]]; then kill "$old" 2>/dev/null || true; fi
  rm -f "$PIDF"
fi
pkill -f 'vllm.entrypoints' 2>/dev/null || true
pkill -f 'vllm serve' 2>/dev/null || true
pkill -f 'sglang.launch_server' 2>/dev/null || true
sleep 2

ARGS=(
  serve "$MODEL_PATH"
  --host "$HOST"
  --port "$PORT"
  --api-key "$LLM_API_KEY"
  --served-model-name "$SERVED_NAME"
  --max-model-len "$CTX"
  --gpu-memory-utilization "$MEM"
  --trust-remote-code
)
if [[ "$PREFIX" == "1" || "$PREFIX" == "true" || "$PREFIX" == "yes" ]]; then
  ARGS+=(--enable-prefix-caching)
fi
if [[ -n "$KV" ]]; then
  ARGS+=(--kv-cache-dtype "$KV")
fi
if [[ -n "$MAX_SEQS" ]]; then
  ARGS+=(--max-num-seqs "$MAX_SEQS")
fi

echo "starting vllm mode=$MODE model=$MODEL_PATH served_as=$SERVED_NAME host=$HOST port=$PORT ctx=$CTX mem=$MEM kv=${KV:-default} max_seqs=${MAX_SEQS:-default}"
if command -v vllm >/dev/null 2>&1; then
  nohup vllm "${ARGS[@]}" >"$LOG" 2>&1 &
else
  # legacy module path
  nohup python -m vllm.entrypoints.openai.api_server \
    --model "$MODEL_PATH" \
    --host "$HOST" \
    --port "$PORT" \
    --api-key "$LLM_API_KEY" \
    --served-model-name "$SERVED_NAME" \
    --max-model-len "$CTX" \
    --gpu-memory-utilization "$MEM" \
    --trust-remote-code \
    $( [[ "$PREFIX" == "1" ]] && echo --enable-prefix-caching ) \
    $( [[ -n "$KV" ]] && echo --kv-cache-dtype "$KV" ) \
    $( [[ -n "$MAX_SEQS" ]] && echo --max-num-seqs "$MAX_SEQS" ) \
    >"$LOG" 2>&1 &
fi

echo $! >"$PIDF"
echo "vllm_started pid=$(cat "$PIDF") log=$LOG mode=$MODE"
echo "vllm:$MODE" >"$LAB/state/last_serve_mode"
date -u +%Y-%m-%dT%H:%M:%SZ >"$LAB/state/last_serve_at"
