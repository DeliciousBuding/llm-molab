# Persistence & fast restore

最后更新：2026-07-19 03:05

## What survives a molab notebook restart

| Path | Survives? | Contents |
|------|-----------|----------|
| `/marimo/models/...` | **Yes** (usually) | HF weights (~35G) |
| `/marimo/llm-lab/.venv-sglang` | **Yes** | SGLang + torch |
| `/marimo/llm-lab/state/serve.env` | **Yes** | Non-secret serve knobs |
| `/marimo/llm-lab/logs` | **Yes** | Prior logs |
| `/marimo/work/llm-molab` | **Yes** | This repo clone |
| `/tmp/.secrets` | **No** | HF / API key / tunnel token |
| Process PIDs / CUDA graphs | **No** | Must relaunch |

**Observed 2026-07-19:** a full molab sandbox **replace** (new `sb-…` id after 410) can wipe `/marimo` even for the same notebook — treat durable paths as “best effort”, not guaranteed. After any new sandbox id, run `11_restore.sh` (it re-downloads / reinstalls if missing). Same-sandbox process restart keeps `/marimo`.

## Durable layout

```text
/marimo/
  models/Qwen3.6-35B-A3B-FP8/     # weights
  llm-lab/
    .venv-sglang/                 # python env
    state/serve.env               # durable non-secret config
    logs/                         # sglang + cloudflared logs
    configs/                      # optional local overrides
  work/llm-molab/                 # git clone of public repo

/tmp/.secrets/                    # RE-INJECT after every cold start
  hf.env
  llm.env
  tunnel.token
```

## After restart (fast path)

On operator machine:

```powershell
molab ensure notebook2
# re-inject secrets (from ~/.config/server-secrets/llm-molab/)
molab fs put notebook2 $env:USERPROFILE\.config\server-secrets\llm-molab\llm.env /tmp/.secrets/llm.env
molab fs put notebook2 $env:USERPROFILE\.config\server-secrets\huggingface\token-download.env /tmp/.secrets/hf.env
molab fs put notebook2 $env:USERPROFILE\.config\server-secrets\cloudflare\tunnel-molab-llm-tmp.token /tmp/.secrets/tunnel.token
molab ssh notebook2 -c "chmod 700 /tmp/.secrets && chmod 600 /tmp/.secrets/*; bash /marimo/work/llm-molab/scripts/11_restore.sh"
```

If the git clone is missing:

```bash
git clone --depth 1 https://github.com/DeliciousBuding/llm-molab.git /marimo/work/llm-molab
```

`11_restore.sh` will:

1. ensure layout + durable `serve.env`
2. require secrets
3. skip model download if `config.json` exists
4. skip venv if importable
5. start SGLang API
6. wait until `/v1/models` is up
7. start cloudflared → `llm.vectorcontrol.tech`

## Tuning without re-download

Edit durable knobs:

```bash
$EDITOR /marimo/llm-lab/state/serve.env
# SERVE_MODE=baseline|prod
# CONTEXT_LENGTH=65536
# MEM_FRACTION_STATIC=0.86
bash /marimo/work/llm-molab/scripts/09_stop_local.sh
bash /marimo/work/llm-molab/scripts/05_serve_api.sh
bash /marimo/work/llm-molab/scripts/10_wait_api.sh
```

API key stays only in `/tmp/.secrets/llm.env` (and operator secret store). Never put it in `serve.env`.

## Operator secret store (Windows)

| File | Role |
|------|------|
| `~/.config/server-secrets/llm-molab/llm.env` | `LLM_API_KEY` + port/path |
| `~/.config/server-secrets/llm-molab/tunnel-meta.txt` | tunnel id / hostname notes |
| `~/.config/server-secrets/cloudflare/tunnel-molab-llm-tmp.token` | CF tunnel token |
| `~/.config/server-secrets/huggingface/token-download.env` | HF download token |

## Cold vs warm

| Scenario | Time driver |
|----------|-------------|
| Warm restore (weights+venv present) | secret inject + model load + tunnel |
| Cold (no weights) | HF download ~35G first |
| Cold (no venv) | `uv pip install sglang[all]` |
