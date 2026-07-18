# llm-molab

最后更新：2026-07-19 03:05

Public runbooks and scripts for running **Qwen3.6-35B-A3B-FP8** on a single
**NVIDIA RTX PRO 6000 Blackwell (96GB)** molab sandbox via **SGLang**, with an
optional temporary Cloudflare named tunnel at `llm.vectorcontrol.tech`.

This repository is **public and secret-free**. Credentials stay in:

- local `~/.config/server-secrets/`
- GitHub Actions / environment secrets
- runtime-only `/tmp/.secrets` inside the sandbox

## What this is

| Item | Value |
|------|--------|
| Model | `Qwen/Qwen3.6-35B-A3B-FP8` (official HF FP8) |
| Host | molab notebook (single GPU) |
| Primary engine | SGLang ≥ 0.5.10 |
| Public name (temp) | `https://llm.vectorcontrol.tech` |
| Auth | OpenAI-compatible API key on the inference server |

## Security rules

1. Never commit tokens, cookies, tunnel credentials, or API keys.
2. Prefer GitHub Secrets / local secret store → inject into sandbox `/tmp/.secrets` only.
3. Tunnel is transport, not auth. Always set `--api-key` on the server.
4. Tear down temporary tunnels and DNS when done (`docs/teardown-tunnel.md`).

## Persistence (fast restart)

Weights, venv, and non-secret config live under **`/marimo`** (durable on the same notebook).
Secrets under **`/tmp/.secrets`** are wiped on sandbox restart — re-inject then:

```bash
bash /marimo/work/llm-molab/scripts/11_restore.sh
```

Details: [docs/persistence.md](docs/persistence.md)

| Durable | Ephemeral |
|---------|-----------|
| `/marimo/models/...` | `/tmp/.secrets/*` |
| `/marimo/llm-lab/.venv-sglang` | process PIDs |
| `/marimo/llm-lab/state/serve.env` | CUDA graphs |
| `/marimo/work/llm-molab` | |

## First boot (sandbox)

```bash
# secrets already in /tmp/.secrets/{hf.env,llm.env,tunnel.token}
bash scripts/00_layout.sh
bash scripts/01_download_model.sh
bash scripts/03_venv_sglang.sh
bash scripts/05_serve_api.sh
bash scripts/10_wait_api.sh
bash scripts/07_cloudflared.sh
# or all-in-one after secrets:
bash scripts/11_restore.sh
```

## Client

```bash
export OPENAI_BASE_URL=https://llm.vectorcontrol.tech/v1
export OPENAI_API_KEY=...   # same as LLM_API_KEY on server
curl "$OPENAI_BASE_URL/models" -H "Authorization: Bearer $OPENAI_API_KEY"
```

## Docs

- [persistence & restore](docs/persistence.md)
- [ops plan](docs/ops-plan.md)
- [secrets](docs/secrets.md)
- [tuning matrix](docs/tuning-matrix.md)
- [teardown tunnel](docs/teardown-tunnel.md)

## License

Apache-2.0 for scripts/docs in this repo. Model weights follow Qwen / Apache-2.0
on Hugging Face.
