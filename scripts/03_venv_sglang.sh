#!/usr/bin/env bash
# Create isolated SGLang venv (durable under /marimo).
# Handles: prerelease flash-attn-4 + Rust for outlines-core source builds.
set -euo pipefail

ROOT="/marimo/llm-lab"
VENV="$ROOT/.venv-sglang"
mkdir -p "$ROOT/state" "$ROOT/logs"
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

# Rust toolchain (needed when outlines-core has no matching wheel)
ensure_rust() {
  if command -v rustc >/dev/null 2>&1; then
    echo "rustc_ok $(rustc --version)"
    return 0
  fi
  echo "installing rustup (for outlines-core build)..."
  export RUSTUP_HOME="${RUSTUP_HOME:-/marimo/llm-lab/.rustup}"
  export CARGO_HOME="${CARGO_HOME:-/marimo/llm-lab/.cargo}"
  mkdir -p "$RUSTUP_HOME" "$CARGO_HOME"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
  # shellcheck disable=SC1091
  source "$CARGO_HOME/env"
  echo "rustc_ok $(rustc --version)"
}
ensure_rust
export RUSTUP_HOME="${RUSTUP_HOME:-/marimo/llm-lab/.rustup}"
export CARGO_HOME="${CARGO_HOME:-/marimo/llm-lab/.cargo}"
# shellcheck disable=SC1091
[[ -f "$CARGO_HOME/env" ]] && source "$CARGO_HOME/env"
export PATH="$CARGO_HOME/bin:$PATH"

if command -v uv >/dev/null 2>&1; then
  rm -rf "$VENV"
  uv venv "$VENV" --python "$PYBIN"
  UVP=(uv pip install --python "$VENV/bin/python" --prerelease=allow)
  # Order: upgrade pip tooling, then sglang
  "${UVP[@]}" -U pip setuptools wheel
  # Prefer binary; still allow source with rust present
  "${UVP[@]}" -U "sglang[all]>=0.5.10" || {
    echo "sglang[all] failed — try core sglang + common extras"
    "${UVP[@]}" -U "sglang>=0.5.10" "openai" "httpx" "uvicorn" "fastapi" "torch"
  }
else
  rm -rf "$VENV"
  "$PYBIN" -m venv "$VENV"
  "$VENV/bin/pip" install -U pip setuptools wheel
  "$VENV/bin/pip" install -U --pre "sglang[all]>=0.5.10"
fi

"$VENV/bin/python" -V
"$VENV/bin/python" - <<'PY'
import torch
print("torch", torch.__version__, "cuda", torch.version.cuda)
print("gpu", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "none")
print("cap", torch.cuda.get_device_capability(0) if torch.cuda.is_available() else None)
import sglang
print("sglang", getattr(sglang, "__version__", "unknown"))
PY
"$VENV/bin/pip" freeze > "$ROOT/requirements-sglang.txt" || true
date -u +%Y-%m-%dT%H:%M:%SZ > "$ROOT/state/venv-sglang.installed_at"
echo "venv_sglang_ok $VENV"
