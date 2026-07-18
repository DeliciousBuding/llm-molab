#!/usr/bin/env bash
# Stop local processes (does not delete CF tunnel/DNS — do that from operator machine).
set -euo pipefail

ROOT="${LLM_LAB:-/marimo/llm-lab}"

for name in sglang cloudflared; do
  pidf="$ROOT/logs/${name}.pid"
  if [[ -f "$pidf" ]]; then
    pid="$(cat "$pidf")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "killing $name pid=$pid"
      kill "$pid" || true
    fi
    rm -f "$pidf"
  fi
done

# also try pkill by pattern (best-effort)
pkill -f 'sglang.launch_server' 2>/dev/null || true
pkill -f 'cloudflared tunnel' 2>/dev/null || true

echo "local_stop_done"
echo "Remember: delete CF tunnel molab-llm-tmp + DNS llm from operator machine when finished."
