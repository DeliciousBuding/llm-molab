#!/usr/bin/env bash
# Fallback engine: vLLM OpenAI-compatible server (if SGLang install fails).
set -euo pipefail

LAB="${LLM_LAB:-/marimo/llm-lab}"
VENV="$LAB/.venv-vllm"
mkdir -p "$LAB/state" "$LAB/logs"

if [[ -x /usr/local/bin/python3.13 ]]; then
  PYBIN=/usr/local/bin/python3.13
else
  PYBIN="$(command -v python3)"
fi

if command -v uv >/dev/null 2>&1; then
  rm -rf "$VENV"
  uv venv "$VENV" --python "$PYBIN"
  uv pip install --python "$VENV/bin/python" -U "vllm>=0.19.0" || \
    uv pip install --python "$VENV/bin/python" -U vllm
else
  rm -rf "$VENV"
  "$PYBIN" -m venv "$VENV"
  "$VENV/bin/pip" install -U pip
  "$VENV/bin/pip" install -U vllm
fi

"$VENV/bin/python" - <<'PY'
import vllm, torch
print("vllm", getattr(vllm, "__version__", "?"))
print("torch", torch.__version__, "cuda", torch.version.cuda)
print("gpu", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "none")
PY
date -u +%Y-%m-%dT%H:%M:%SZ > "$LAB/state/venv-vllm.installed_at"
echo "venv_vllm_ok $VENV"
