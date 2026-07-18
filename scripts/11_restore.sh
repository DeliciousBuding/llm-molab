#!/usr/bin/env bash
# One-shot restore after notebook relaunch.
# Assumes weights/venv may already exist under /marimo; secrets must be re-injected to /tmp/.secrets.
set -euo pipefail

REPO="${REPO_DIR:-/marimo/work/llm-molab}"
LAB="${LLM_LAB:-/marimo/llm-lab}"
MODEL="${MODEL_PATH:-/marimo/models/Qwen3.6-35B-A3B-FP8}"

echo "== restore begin =="

# 1) layout
bash "$REPO/scripts/00_layout.sh"

# 2) secrets gate
need=0
for f in hf.env llm.env tunnel.token; do
  if [[ ! -s "/tmp/.secrets/$f" ]]; then
    echo "MISSING /tmp/.secrets/$f" >&2
    need=1
  fi
done
if [[ "$need" -ne 0 ]]; then
  cat >&2 <<'EOF'
Secrets are runtime-only under /tmp/.secrets and do not survive sandbox restart.
Re-inject from operator machine, then re-run this script:

  molab fs put notebook2 <local>/hf.env /tmp/.secrets/hf.env
  molab fs put notebook2 <local>/llm.env /tmp/.secrets/llm.env
  molab fs put notebook2 <local>/tunnel.token /tmp/.secrets/tunnel.token
  molab ssh notebook2 -c 'chmod 700 /tmp/.secrets && chmod 600 /tmp/.secrets/*'

Operator secret store (example):
  ~/.config/server-secrets/llm-molab/
  ~/.config/server-secrets/huggingface/token-download.env
  ~/.config/server-secrets/cloudflare/tunnel-molab-llm-tmp.token
EOF
  exit 2
fi

# 3) model
if [[ ! -f "$MODEL/config.json" ]]; then
  echo "model missing — downloading"
  bash "$REPO/scripts/01_download_model.sh"
else
  echo "model_ok $(du -sh "$MODEL" | awk '{print $1}')"
fi

# 4) venv
if [[ ! -x "$LAB/.venv-sglang/bin/python" ]]; then
  echo "venv missing — installing"
  bash "$REPO/scripts/03_venv_sglang.sh"
else
  echo "venv_ok"
  "$LAB/.venv-sglang/bin/python" -c "import sglang,torch; print('sglang', getattr(sglang,'__version__','?'), 'torch', torch.__version__)" || {
    echo "venv broken — reinstall"
    bash "$REPO/scripts/03_venv_sglang.sh"
  }
fi

# 5) serve API
bash "$REPO/scripts/05_serve_api.sh"
bash "$REPO/scripts/10_wait_api.sh"

# 6) tunnel
bash "$REPO/scripts/07_cloudflared.sh"

echo "== restore done =="
echo "local:  http://127.0.0.1:8000/v1"
echo "public: https://llm.vectorcontrol.tech/v1"
echo "auth:   Bearer \$LLM_API_KEY (from /tmp/.secrets/llm.env)"
