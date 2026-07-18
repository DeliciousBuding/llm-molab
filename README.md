# llm-molab

最后更新：2026-07-19 02:45

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
| Alt engine | vLLM ≥ 0.19.0 |
| Public name (temp) | `https://llm.vectorcontrol.tech` |
| Auth | OpenAI-compatible API key on the inference server |

## Security rules

1. Never commit tokens, cookies, tunnel credentials, or API keys.
2. Prefer GitHub Secrets / local secret store → inject into sandbox `/tmp/.secrets` only.
3. Tunnel is transport, not auth. Always set `--api-key` on the server.
4. Tear down temporary tunnels and DNS when done (`scripts/teardown_tunnel.md`).

## Layout

```text
scripts/     # bash helpers for sandbox
configs/     # non-secret templates
docs/        # ops notes
```

## Quick path (sandbox)

```bash
# 1) secrets already in /tmp/.secrets/{hf.env,llm.env,tunnel.token}
bash scripts/00_layout.sh
bash scripts/01_download_model.sh
bash scripts/03_venv_sglang.sh
bash scripts/04_serve_baseline.sh    # smoke
# later:
bash scripts/06_serve_prod_candidate.sh
bash scripts/07_cloudflared.sh
```

## Client

```bash
export OPENAI_BASE_URL=https://llm.vectorcontrol.tech/v1
export OPENAI_API_KEY=...   # same as LLM_API_KEY on server
```

## Docs

- [ops plan](docs/ops-plan.md)
- [secrets](docs/secrets.md)
- [tuning matrix](docs/tuning-matrix.md)

## License

Apache-2.0 for scripts/docs in this repo. Model weights follow Qwen / Apache-2.0
on Hugging Face.
