#!/usr/bin/env bash
# Prefer SGLang; if venv missing/broken, try install; if still fails, vLLM.
set -euo pipefail

REPO="${REPO_DIR:-/marimo/work/llm-molab}"
LAB="${LLM_LAB:-/marimo/llm-lab}"

bash "$REPO/scripts/00_layout.sh"

need=0
for f in llm.env tunnel.token; do
  if [[ ! -s "/tmp/.secrets/$f" ]]; then
    echo "MISSING /tmp/.secrets/$f" >&2
    need=1
  fi
done
if [[ "$need" -ne 0 ]]; then
  echo "inject secrets then re-run" >&2
  exit 2
fi

MODEL="${MODEL_PATH:-/marimo/models/Qwen3.6-35B-A3B-FP8}"
if [[ ! -f "$MODEL/config.json" ]]; then
  [[ -s /tmp/.secrets/hf.env ]] || { echo "need hf.env for download" >&2; exit 2; }
  bash "$REPO/scripts/01_download_model.sh"
else
  echo "model_ok"
fi

ENGINE=sglang
if [[ ! -x "$LAB/.venv-sglang/bin/python" ]] || ! "$LAB/.venv-sglang/bin/python" -c "import sglang" 2>/dev/null; then
  echo "installing sglang..."
  if ! bash "$REPO/scripts/03_venv_sglang.sh"; then
    echo "sglang install failed — falling back to vLLM"
    ENGINE=vllm
    bash "$REPO/scripts/03b_venv_vllm.sh"
  fi
fi

if [[ "$ENGINE" == "sglang" ]]; then
  bash "$REPO/scripts/05_serve_api.sh"
else
  bash "$REPO/scripts/05b_serve_vllm.sh"
fi

bash "$REPO/scripts/10_wait_api.sh"
bash "$REPO/scripts/07_cloudflared.sh"
echo "api_up engine=$ENGINE"
