#!/usr/bin/env bash
# Ensure weights under /marimo/models — package-first fixed path.
# If package keeps them across remint, this is a no-op (max efficiency).
set -euo pipefail

if [[ -f /tmp/.secrets/hf.env ]]; then
  # shellcheck disable=SC1091
  set -a; source /tmp/.secrets/hf.env; set +a
fi
: "${HF_TOKEN:=${HUGGING_FACE_HUB_TOKEN:-}}"

MODEL_ID="${MODEL_ID:-Qwen/Qwen3.6-35B-A3B-FP8}"
LOCAL_DIR="${MODEL_PATH:-/marimo/models/Qwen3.6-35B-A3B-FP8}"
mkdir -p "$LOCAL_DIR"

ok=0
if [[ -f "$LOCAL_DIR/config.json" ]]; then
  if compgen -G "$LOCAL_DIR/*.safetensors" >/dev/null || compgen -G "$LOCAL_DIR/layers-*.safetensors" >/dev/null; then
    ok=1
  fi
fi
if [[ "$ok" -eq 1 ]]; then
  echo "model_ok package_hit $LOCAL_DIR $(du -sh "$LOCAL_DIR" | awk '{print $1}')"
  exit 0
fi

if [[ -z "${HF_TOKEN:-}" ]]; then
  echo "HF_TOKEN missing — cannot fill package model dir" >&2
  exit 1
fi

export HF_TOKEN HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"
export HF_HOME="${HF_HOME:-/tmp/hf-cache}"
export HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-1}"
# Prefer materializing INTO /marimo/models (package tree), not only hub cache
export MODEL_ID MODEL_PATH="$LOCAL_DIR"

echo "model_miss — downloading into package path $LOCAL_DIR"
if command -v hf >/dev/null 2>&1; then
  hf download "$MODEL_ID" --local-dir "$LOCAL_DIR" --token "$HF_TOKEN"
elif command -v huggingface-cli >/dev/null 2>&1; then
  huggingface-cli download "$MODEL_ID" --local-dir "$LOCAL_DIR" --token "$HF_TOKEN"
else
  python3 - <<'PY'
import os
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id=os.environ["MODEL_ID"],
    local_dir=os.environ["MODEL_PATH"],
    token=os.environ["HF_TOKEN"],
)
print("snapshot_ok")
PY
fi

test -f "$LOCAL_DIR/config.json"
# stamp for package probe
date -u +%Y-%m-%dT%H:%M:%SZ >"$LOCAL_DIR/.package_downloaded_at"
echo "model_ensured package_path $(du -sh "$LOCAL_DIR" | awk '{print $1}')"
