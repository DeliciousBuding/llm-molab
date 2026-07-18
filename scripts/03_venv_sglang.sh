#!/usr/bin/env bash
# Create isolated SGLang venv (absolute paths; molab-safe; durable under /marimo).
set -euo pipefail

ROOT="/marimo/llm-lab"
VENV="$ROOT/.venv-sglang"
mkdir -p "$ROOT"
cd "$ROOT"

if [[ -x /usr/local/bin/python3.13 ]]; then
  PYBIN=/usr/local/bin/python3.13
elif [[ -x /usr/bin/python3 ]]; then
  PYBIN=/usr/bin/python3
else
  PYBIN="$(command -v python3)"
fi
echo "using_python=$PYBIN"
"$PYBIN" -V

if command -v uv >/dev/null 2>&1; then
  rm -rf "$VENV"
  uv venv "$VENV" --python "$PYBIN"
  # flash-attn-4 is pre-release on PyPI
  uv pip install --python "$VENV/bin/python" --prerelease=allow -U "sglang[all]>=0.5.10"
else
  rm -rf "$VENV"
  "$PYBIN" -m venv "$VENV"
  "$VENV/bin/pip" install -U pip
  "$VENV/bin/pip" install -U --pre "sglang[all]>=0.5.10"
fi

"$VENV/bin/python" -V
"$VENV/bin/python" - <<'PY'
import torch
print("torch", torch.__version__, "cuda", torch.version.cuda)
print("gpu", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "none")
print("cap", torch.cuda.get_device_capability(0) if torch.cuda.is_available() else None)
try:
    import sglang
    print("sglang", getattr(sglang, "__version__", "unknown"))
except Exception as e:
    print("sglang_import_error", e)
    raise
PY
"$VENV/bin/pip" freeze > "$ROOT/requirements-sglang.txt" || true
# mark durable install stamp
date -u +%Y-%m-%dT%H:%M:%SZ > "$ROOT/state/venv-sglang.installed_at" 2>/dev/null || true
echo "venv_sglang_ok $VENV"
