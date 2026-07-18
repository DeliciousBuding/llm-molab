#!/usr/bin/env bash
# Start SGLang OpenAI-compatible API.
# Reads durable knobs from /marimo/llm-lab/state/serve.env (no secrets).
# Reads LLM_API_KEY from /tmp/.secrets/llm.env.
set -euo pipefail

LAB="${LLM_LAB:-/marimo/llm-lab}"
REPO="${REPO_DIR:-/marimo/work/llm-molab}"

if [[ -f "$LAB/state/serve.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$LAB/state/serve.env"; set +a
fi
if [[ -f /tmp/.secrets/llm.env ]]; then
  # shellcheck disable=SC1091
  set -a; source /tmp/.secrets/llm.env; set +a
fi

: "${LLM_API_KEY:?set LLM_API_KEY in /tmp/.secrets/llm.env}"
MODEL_PATH="${MODEL_PATH:-/marimo/models/Qwen3.6-35B-A3B-FP8}"
HOST="${SERVE_HOST:-127.0.0.1}"
PORT="${SERVE_PORT:-8000}"
MODE="${SERVE_MODE:-prod}"
LOG="$LAB/logs/sglang-api.log"
PIDF="$LAB/logs/sglang.pid"

# shellcheck disable=SC1091
source "$LAB/.venv-sglang/bin/activate"
mkdir -p "$LAB/logs"

if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
  echo "already_running pid=$(cat "$PIDF")"
  exit 0
fi
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
    --context-length "${CONTEXT_LENGTH:-32768}"
    --mem-fraction-static "${MEM_FRACTION_STATIC:-0.80}"
  )
else
  ARGS=(
    "${COMMON[@]}"
    --context-length "${CONTEXT_LENGTH:-131072}"
    --mem-fraction-static "${MEM_FRACTION_STATIC:-0.88}"
    --chunked-prefill-size "${CHUNKED_PREFILL_SIZE:-8192}"
  )
  if [[ -n "${KV_CACHE_DTYPE:-}" ]]; then
    ARGS+=(--kv-cache-dtype "$KV_CACHE_DTYPE")
  fi
  if [[ "${ENABLE_MTP:-1}" == "1" ]]; then
    ARGS+=(
      --speculative-algo NEXTN
      --speculative-num-steps "${MTP_STEPS:-3}"
      --speculative-eagle-topk "${MTP_TOPK:-1}"
      --speculative-num-draft-tokens "${MTP_DRAFT_TOKENS:-4}"
    )
  fi
fi

echo "starting mode=$MODE host=$HOST port=$PORT model=$MODEL_PATH log=$LOG"
nohup python -m sglang.launch_server "${ARGS[@]}" >"$LOG" 2>&1 &
echo $! >"$PIDF"
echo "started pid=$(cat "$PIDF")"
echo "$MODE" >"$LAB/state/last_serve_mode"
date -u +%Y-%m-%dT%H:%M:%SZ >"$LAB/state/last_serve_at"
