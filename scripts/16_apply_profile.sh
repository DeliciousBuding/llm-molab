#!/usr/bin/env bash
# Apply a named serve profile into /marimo/llm-lab/state/serve.env (no secrets).
# usage: bash scripts/16_apply_profile.sh baseline|fast|long
set -euo pipefail

PROFILE="${1:-}"
if [[ -z "$PROFILE" ]]; then
  echo "usage: $0 baseline|fast|long" >&2
  exit 2
fi

REPO="${REPO_DIR:-/marimo/work/llm-molab}"
LAB="${LLM_LAB:-/marimo/llm-lab}"
SRC="$REPO/configs/serve.${PROFILE}.env"
DST="$LAB/state/serve.env"

if [[ ! -f "$SRC" ]]; then
  # local checkout fallback
  if [[ -f "configs/serve.${PROFILE}.env" ]]; then
    SRC="configs/serve.${PROFILE}.env"
  else
    echo "missing profile file: $SRC" >&2
    exit 1
  fi
fi

mkdir -p "$LAB/state"
cp "$SRC" "$DST"
# strip Windows CRLF if any
sed -i 's/\r$//' "$DST" 2>/dev/null || true
echo "profile_applied name=$PROFILE path=$DST"
grep -E '^(SERVE_MODE|CONTEXT_LENGTH|MEM_FRACTION_STATIC|KV_CACHE_DTYPE|MAX_NUM_SEQS|ENGINE)=' "$DST" || true
