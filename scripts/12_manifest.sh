#!/usr/bin/env bash
# Write inventory under /marimo/llm-lab/state (package tree).
set -euo pipefail

LAB="${LLM_LAB:-/marimo/llm-lab}"
MODEL="${MODEL_PATH:-/marimo/models/Qwen3.6-35B-A3B-FP8}"
mkdir -p "$LAB/state"

cmd="${1:-write}"
export LLM_LAB="$LAB" MODEL_PATH="$MODEL"

if [[ "$cmd" == "write" ]]; then
  python3 - <<'PY'
import json, os, time, hashlib
from pathlib import Path
lab = Path(os.environ.get("LLM_LAB", "/marimo/llm-lab"))
model = Path(os.environ.get("MODEL_PATH", "/marimo/models/Qwen3.6-35B-A3B-FP8"))
out = lab / "state" / "MANIFEST.json"

def dir_size(p: Path) -> int:
    t = 0
    if not p.exists():
        return 0
    for root, _, files in os.walk(p):
        for f in files:
            try:
                t += (Path(root) / f).stat().st_size
            except OSError:
                pass
    return t

cfg = model / "config.json"
data = {
    "schema": "llm-molab.manifest/v1",
    "policy": "package-first",
    "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "model_path": str(model),
    "model_config_exists": cfg.is_file(),
    "model_bytes": dir_size(model),
    "venv_vllm": (lab / ".venv-vllm/bin/python").exists(),
    "venv_sglang": (lab / ".venv-sglang/bin/python").exists(),
    "cloudflared_bin": Path("/marimo/bin/cloudflared").exists(),
    "cloudflared_legacy": (lab / "cf/cloudflared").exists(),
    "serve_env": (lab / "state/serve.env").exists(),
    "repo": Path("/marimo/work/llm-molab/.git").exists(),
}
out.write_text(json.dumps(data, indent=2) + "\n")
print("manifest_written", out)
print(json.dumps({k: data[k] for k in ("model_config_exists", "model_bytes", "venv_vllm", "cloudflared_bin")}, indent=2))
PY
elif [[ "$cmd" == "verify" ]]; then
  python3 - <<'PY'
import os, sys
from pathlib import Path
lab = Path(os.environ.get("LLM_LAB", "/marimo/llm-lab"))
model = Path(os.environ.get("MODEL_PATH", "/marimo/models/Qwen3.6-35B-A3B-FP8"))
ok = True
for label, cond in [
    ("model", (model / "config.json").is_file()),
    ("venv", (lab / ".venv-vllm/bin/python").exists() or (lab / ".venv-sglang/bin/python").exists()),
    ("cloudflared", Path("/marimo/bin/cloudflared").exists() or (lab / "cf/cloudflared").exists()),
]:
    print(("OK" if cond else "FAIL"), label)
    ok = ok and (cond if label != "cloudflared" else True)  # cloudflared soft
    if label != "cloudflared" and not cond:
        ok = False
sys.exit(0 if (model / "config.json").is_file() else 1)
PY
else
  echo "usage: $0 write|verify" >&2
  exit 2
fi
