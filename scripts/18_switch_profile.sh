#!/usr/bin/env bash
# Switch profile on a live sandbox (model already present). Restarts vLLM + tunnel.
# usage: bash scripts/18_switch_profile.sh fast
set -euo pipefail

PROFILE="${1:-}"
if [[ -z "$PROFILE" ]]; then
  echo "usage: $0 baseline|fast|long" >&2
  exit 2
fi

REPO="${REPO_DIR:-/marimo/work/llm-molab}"
LAB="${LLM_LAB:-/marimo/llm-lab}"

bash "$REPO/scripts/16_apply_profile.sh" "$PROFILE"
# shellcheck disable=SC1091
set -a; source "$LAB/state/serve.env"; set +a

ENGINE="${ENGINE:-vllm}"
if [[ "$ENGINE" == "vllm" ]]; then
  bash "$REPO/scripts/05b_serve_vllm.sh"
else
  bash "$REPO/scripts/05_serve_api.sh"
fi
bash "$REPO/scripts/10_wait_api.sh"
export PATH="/marimo/bin:/marimo/llm-lab/cf:$PATH"
bash "$REPO/scripts/07_cloudflared.sh" || true
bash "$REPO/scripts/17_watchdog.sh" once || true
echo "switched profile=$PROFILE engine=$ENGINE"
echo "bench: python3 $REPO/scripts/20_bench.py --profile $PROFILE"
