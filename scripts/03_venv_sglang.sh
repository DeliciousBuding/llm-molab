#!/usr/bin/env bash
# Create isolated SGLang venv.
set -euo pipefail

ROOT="${LLM_LAB:-/marimo/llm-lab}"
VENV="$ROOT/.venv-sglang"
PY="${PYTHON:-python3.12}"

mkdir -p "$ROOT"
if ! command -v "$PY" >/dev/null 2>&1; then
  PY=python3
fi

if command -v uv >/dev/null 2>&1; then
  uv venv "$VENV" --python "$PY" || uv venv "$VENV" --python 3.13
  # shellcheck disable=SC1091
  source "$VENV/bin/activate"
  uv pip install -U "sglang[all]>=0.5.10"
else
  "$PY" -m venv "$VENV"
  # shellcheck disable=SC1091
  source "$VENV/bin/activate"
  pip install -U pip
  pip install -U "sglang[all]>=0.5.10"
fi

python -V
python - <<'PY'
import torch
print("torch", torch.__version__, "cuda", torch.version.cuda)
print("gpu", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "none")
print("cap", torch.cuda.get_device_capability(0) if torch.cuda.is_available() else None)
PY
pip freeze > "$ROOT/requirements-sglang.txt"
echo "venv_sglang_ok $VENV"
