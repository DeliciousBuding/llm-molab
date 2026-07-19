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

## Persistence (package-first)

**有配额就把权重/venv/cloudflared 塞进 `/marimo` package 树**，remint 后能命中就不再下。  
密钥只在 `/tmp/.secrets`。见 [docs/persistence.md](docs/persistence.md)。

```bash
bash scripts/15_probe_package_quota.sh probe   # 看占用
bash scripts/11_restore.sh                     # ensure 全套 + 起 API
# remint 后再:
bash scripts/15_probe_package_quota.sh verify
```

| Package 路径 (`/marimo`) | `/tmp` only |
|--------------------------|-------------|
| `models/…` 权重 | `.secrets/*` |
| `llm-lab/.venv-vllm` | job 日志 |
| `bin/cloudflared` | |
| `llm-lab/state/serve.env` | |

## Profiles & bench

| Profile | 要点 |
|---------|------|
| `baseline` | 32K · mem 0.80 · 保命 |
| `fast` | 32K · mem **0.88** · max-num-seqs 32 |
| `long` | 128K · FP8 KV · 需 A/B |

```bash
bash scripts/16_apply_profile.sh fast
bash scripts/05b_serve_vllm.sh && bash scripts/10_wait_api.sh
python3 scripts/20_bench.py --profile fast
bash scripts/17_watchdog.sh once   # API + tunnel 自愈检查
```

### Windows operator（本机）

```powershell
cd D:\Code\llm\llm-molab
.\scripts\windows\BringUp-LlmApi.ps1 -Account notebook2 -Profile fast -RunBench
# 或分步:
# .\scripts\windows\Wait-MolabReady.ps1 -Account notebook2 -EnsureOnce
# .\scripts\windows\Restore-LlmApi.ps1 -Account notebook2 -Profile fast
# .\scripts\windows\Smoke-LlmApi.ps1
# .\scripts\windows\Bench-LlmApi.ps1 -Profile fast
```

详表见 [docs/tuning-matrix.md](docs/tuning-matrix.md) · 恢复 [docs/operator-restore.md](docs/operator-restore.md) · 客户端 [docs/client.md](docs/client.md)。

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
# Current vLLM id is the path unless --served-model-name is set:
export MODEL_ID="/marimo/models/Qwen3.6-35B-A3B-FP8"
curl "$OPENAI_BASE_URL/models" -H "Authorization: Bearer $OPENAI_API_KEY"
curl "$OPENAI_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL_ID\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":64}"
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
