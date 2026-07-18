#!/usr/bin/env bash
# Create isolated SGLang venv (absolute paths; molab-safe).
set -euo pipefail

ROOT="/marimo/llm-lab"
VENV="$ROOT/.venv-sglang"
mkdir -p "$ROOT"
cd "$ROOT"

# Prefer system 3.13 on molab images; fall back to whatever python3 is.
PYBIN="$(command -v python3.13 || command -v python3)"
echo "using_python=$PYBIN"
"$PYBIN" -V

if command -v uv >/dev/null 2>&1; then
  # Always create with absolute path; never rely on cwd project discovery.
  rm -rf "$VENV"
  uv venv "$VENV" --python "$PYBIN"
  uv pip install --python "$VENV/bin/python" -U "sglang[all]>=0.5.10"
else
  rm -rf "$VENV"
  "$PYBIN" -m venv "$VENV"
  "$VENV/bin/pip" install -U pip
  "$VENV/bin/pip" install -U "sglang[all]>=0.5.10"
fi

"$VENV/bin/python" -V
"$VENV/bin/python" - <<'PY'
import torch
print("torch", torch.__version__, "cuda", torch.version.cuda)
print("gpu", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "none")
print("cap", torch.cuda.get_device_capability(0) if torch.cuda.is_available() else None)
PY
"$VENV/bin/pip" freeze > "$ROOT/requirements-sglang.txt"
echo "venv_sglang_ok $VENV"
