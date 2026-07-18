#!/usr/bin/env bash
# Prefer durable engine selection from serve.env (vllm default for reliability).
set -euo pipefail

REPO="${REPO_DIR:-/marimo/work/llm-molab}"
LAB="${LLM_LAB:-/marimo/llm-lab}"

bash "$REPO/scripts/00_layout.sh"
if [[ -f "$LAB/state/serve.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$LAB/state/serve.env"; set +a
fi

need=0
for f in llm.env tunnel.token; do
  if [[ ! -s "/tmp/.secrets/$f" ]]; then
    echo "MISSING /tmp/.secrets/$f" >&2
    need=1
  fi
done
if [[ "$need" -ne 0 ]]; then
  echo "inject secrets then re-run (see docs/operator-restore.md)" >&2
  exit 2
fi

# strip CR from secrets
for f in /tmp/.secrets/*; do
  [[ -f "$f" ]] || continue
  sed -i 's/\r$//' "$f" 2>/dev/null || true
done

MODEL="${MODEL_PATH:-/marimo/models/Qwen3.6-35B-A3B-FP8}"
if [[ ! -f "$MODEL/config.json" ]]; then
  [[ -s /tmp/.secrets/hf.env ]] || { echo "need hf.env for download" >&2; exit 2; }
  bash "$REPO/scripts/01_download_model.sh"
else
  echo "model_ok $(du -sh "$MODEL" | awk '{print $1}')"
fi

ENGINE="${ENGINE:-vllm}"
if [[ "$ENGINE" == "sglang" ]]; then
  if [[ ! -x "$LAB/.venv-sglang/bin/python" ]] || ! "$LAB/.venv-sglang/bin/python" -c "import sglang" 2>/dev/null; then
    echo "installing sglang..."
    if ! bash "$REPO/scripts/03_venv_sglang.sh"; then
      echo "sglang install failed — falling back to vLLM"
      ENGINE=vllm
    fi
  fi
fi

if [[ "$ENGINE" == "vllm" ]]; then
  if [[ ! -x "$LAB/.venv-vllm/bin/python" ]] || ! "$LAB/.venv-vllm/bin/python" -c "import vllm" 2>/dev/null; then
    bash "$REPO/scripts/03b_venv_vllm.sh"
  else
    echo "venv_vllm_ok"
  fi
  bash "$REPO/scripts/05b_serve_vllm.sh"
else
  bash "$REPO/scripts/05_serve_api.sh"
fi

bash "$REPO/scripts/10_wait_api.sh"
bash "$REPO/scripts/07_cloudflared.sh"
echo "api_up engine=$ENGINE"
echo "local  http://127.0.0.1:8000/v1"
echo "public https://llm.vectorcontrol.tech/v1"
