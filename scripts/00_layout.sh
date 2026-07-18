#!/usr/bin/env bash
# Create dirs under /marimo package tree.
set -euo pipefail

mkdir -p /marimo/bin
mkdir -p /marimo/llm-lab/{scripts,configs,logs,bench,cf,state,venvs}
mkdir -p /marimo/models
mkdir -p /marimo/work
mkdir -p /tmp/.secrets /tmp/hf-cache /tmp/llm-runtime
chmod 700 /tmp/.secrets 2>/dev/null || true

STATE_ENV=/marimo/llm-lab/state/serve.env
EXAMPLE=/marimo/work/llm-molab/configs/serve.env.example
if [[ ! -f "$STATE_ENV" ]]; then
  if [[ -f "$EXAMPLE" ]]; then
    cp "$EXAMPLE" "$STATE_ENV"
  else
    cat >"$STATE_ENV" <<'EOF'
MODEL_PATH=/marimo/models/Qwen3.6-35B-A3B-FP8
SERVED_MODEL_NAME=Qwen3.6-35B-A3B-FP8
SERVE_HOST=127.0.0.1
SERVE_PORT=8000
SERVE_MODE=baseline
CONTEXT_LENGTH=32768
MEM_FRACTION_STATIC=0.80
ENGINE=vllm
TUNNEL_HOSTNAME=llm.vectorcontrol.tech
LLM_LAB=/marimo/llm-lab
REPO_DIR=/marimo/work/llm-molab
EOF
  fi
fi

mkdir -p /tmp/llm-runtime
ln -sfn /marimo/llm-lab/logs /tmp/llm-runtime/logs 2>/dev/null || true

echo "layout_ok package_root=/marimo"
echo "bin=/marimo/bin models=/marimo/models lab=/marimo/llm-lab"
df -h /marimo /tmp 2>/dev/null || true
nvidia-smi -L || true
