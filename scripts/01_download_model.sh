#!/usr/bin/env bash
# Download official FP8 weights via Hugging Face CLI.
set -euo pipefail

if [[ -f /tmp/.secrets/hf.env ]]; then
  # shellcheck disable=SC1091
  set -a; source /tmp/.secrets/hf.env; set +a
fi

: "${HF_TOKEN:=${HUGGING_FACE_HUB_TOKEN:-}}"
if [[ -z "${HF_TOKEN:-}" ]]; then
  echo "HF_TOKEN missing — put it in /tmp/.secrets/hf.env" >&2
  exit 1
fi

export HF_TOKEN
export HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"
export HF_HOME="${HF_HOME:-/tmp/hf-cache}"
export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"

MODEL_ID="${MODEL_ID:-Qwen/Qwen3.6-35B-A3B-FP8}"
LOCAL_DIR="${MODEL_PATH:-/marimo/models/Qwen3.6-35B-A3B-FP8}"

mkdir -p "$LOCAL_DIR"
echo "downloading $MODEL_ID -> $LOCAL_DIR"

if command -v hf >/dev/null 2>&1; then
  hf download "$MODEL_ID" --local-dir "$LOCAL_DIR" --token "$HF_TOKEN"
elif command -v huggingface-cli >/dev/null 2>&1; then
  huggingface-cli download "$MODEL_ID" --local-dir "$LOCAL_DIR" --token "$HF_TOKEN"
else
  python3 - <<'PY'
import os
from huggingface_hub import snapshot_download
mid = os.environ.get("MODEL_ID", "Qwen/Qwen3.6-35B-A3B-FP8")
local = os.environ.get("MODEL_PATH", "/marimo/models/Qwen3.6-35B-A3B-FP8")
snapshot_download(repo_id=mid, local_dir=local, token=os.environ["HF_TOKEN"])
print("snapshot_download_done", local)
PY
fi

echo "download_done"
du -sh "$LOCAL_DIR"
ls -la "$LOCAL_DIR" | head -30
