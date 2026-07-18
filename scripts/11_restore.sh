#!/usr/bin/env bash
# Package-first restore: keep everything under /marimo; secrets only in /tmp.
set -euo pipefail

REPO="${REPO_DIR:-/marimo/work/llm-molab}"
LAB="${LLM_LAB:-/marimo/llm-lab}"

if [[ ! -d "$REPO/.git" ]]; then
  mkdir -p /marimo/work
  git clone --depth 1 https://github.com/DeliciousBuding/llm-molab.git "$REPO"
fi
cd "$REPO"
git fetch origin 2>/dev/null || true
git reset --hard origin/main 2>/dev/null || true
chmod +x "$REPO"/scripts/*.sh 2>/dev/null || true

bash "$REPO/scripts/00_layout.sh"
if [[ ! -f "$LAB/state/serve.env" ]]; then
  cp "$REPO/configs/serve.env.example" "$LAB/state/serve.env"
fi
# shellcheck disable=SC1091
set -a; source "$LAB/state/serve.env"; set +a

need=0
for f in llm.env tunnel.token; do
  if [[ ! -s "/tmp/.secrets/$f" ]]; then
    echo "MISSING /tmp/.secrets/$f" >&2
    need=1
  fi
done
if [[ "$need" -ne 0 ]]; then
  echo "inject secrets (see docs/operator-restore.md) then re-run" >&2
  exit 2
fi
for f in /tmp/.secrets/*; do
  [[ -f "$f" ]] || continue
  sed -i 's/\r$//' "$f" 2>/dev/null || true
done

# 1) tools + model under /marimo (package tree)
bash "$REPO/scripts/13_ensure_cloudflared.sh"
bash "$REPO/scripts/14_ensure_model.sh"

# 2) engine venv under /marimo/llm-lab
ENGINE="${ENGINE:-vllm}"
if [[ "$ENGINE" == "sglang" ]]; then
  if [[ ! -x "$LAB/.venv-sglang/bin/python" ]] || ! "$LAB/.venv-sglang/bin/python" -c "import sglang" 2>/dev/null; then
    bash "$REPO/scripts/03_venv_sglang.sh" || ENGINE=vllm
  fi
fi
if [[ "$ENGINE" == "vllm" ]]; then
  if [[ ! -x "$LAB/.venv-vllm/bin/python" ]] || ! "$LAB/.venv-vllm/bin/python" -c "import vllm" 2>/dev/null; then
    bash "$REPO/scripts/03b_venv_vllm.sh"
  else
    echo "venv_vllm_ok (package path)"
  fi
  bash "$REPO/scripts/05b_serve_vllm.sh"
else
  bash "$REPO/scripts/05_serve_api.sh"
fi

bash "$REPO/scripts/10_wait_api.sh"

# cloudflared prefer /marimo/bin
export PATH="/marimo/bin:/marimo/llm-lab/cf:$PATH"
bash "$REPO/scripts/07_cloudflared.sh"

bash "$REPO/scripts/12_manifest.sh" write 2>/dev/null || true
bash "$REPO/scripts/15_probe_package_quota.sh" probe || true

echo "api_up engine=$ENGINE package_root=/marimo"
echo "local  http://127.0.0.1:${SERVE_PORT:-8000}/v1"
echo "public https://${TUNNEL_HOSTNAME:-llm.vectorcontrol.tech}/v1"
