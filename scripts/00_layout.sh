#!/usr/bin/env bash
# Create durable dirs on molab sandbox.
# /marimo  = 相对持久（权重、venv、配置、日志）
# /tmp     = 易失（密钥、下载缓存、PID）
set -euo pipefail

mkdir -p /marimo/llm-lab/{scripts,configs,logs,bench,cf,state,venvs}
mkdir -p /marimo/models
mkdir -p /marimo/work
mkdir -p /tmp/.secrets /tmp/hf-cache /tmp/llm-runtime
chmod 700 /tmp/.secrets 2>/dev/null || true

# Durable non-secret defaults (safe to commit / re-clone)
STATE_ENV=/marimo/llm-lab/state/serve.env
if [[ ! -f "$STATE_ENV" ]]; then
  cat >"$STATE_ENV" <<'EOF'
# Durable serve defaults — NO secrets in this file.
MODEL_PATH=/marimo/models/Qwen3.6-35B-A3B-FP8
SERVE_HOST=127.0.0.1
SERVE_PORT=8000
SERVE_MODE=prod
CONTEXT_LENGTH=131072
MEM_FRACTION_STATIC=0.88
CHUNKED_PREFILL_SIZE=8192
KV_CACHE_DTYPE=fp8_e4m3
ENABLE_MTP=1
MTP_STEPS=3
MTP_TOPK=1
MTP_DRAFT_TOKENS=4
TUNNEL_HOSTNAME=llm.vectorcontrol.tech
LLM_LAB=/marimo/llm-lab
REPO_DIR=/marimo/work/llm-molab
EOF
fi

# PID / runtime pointers live under /tmp (sandbox process space)
mkdir -p /tmp/llm-runtime
ln -sfn /marimo/llm-lab/logs /tmp/llm-runtime/logs 2>/dev/null || true

echo "layout_ok"
echo "durable_state=$STATE_ENV"
df -h /marimo /tmp 2>/dev/null || true
nvidia-smi -L || true
