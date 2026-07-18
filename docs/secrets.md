# Secrets handling

最后更新：2026-07-19 02:45

## Principle

Public repo holds **templates only**. Live secrets:

| Source | Examples |
|--------|----------|
| Local operator machine | `~/.config/server-secrets/huggingface/`, `cloudflare/`, `github/` |
| GitHub Secrets (optional CI) | `HF_TOKEN`, `LLM_API_KEY`, tunnel token |
| Sandbox runtime | `/tmp/.secrets/*` (mode 600, deleted after session) |

## Recommended inject flow (molab)

1. On the operator machine, write short-lived files under a local temp dir.
2. `molab fs put notebook2 <local> /tmp/.secrets/<name>`
3. Inside sandbox: `set -a; source /tmp/.secrets/hf.env; set +a`
4. On teardown: `shred -u` / `rm -f /tmp/.secrets/*`

Never `echo` secret values into job logs or chat.

## Minimum files on sandbox

| Path | Content |
|------|---------|
| `/tmp/.secrets/hf.env` | `HF_TOKEN=...` |
| `/tmp/.secrets/llm.env` | `LLM_API_KEY=...` |
| `/tmp/.secrets/tunnel.token` | Cloudflare tunnel token (single line) |

Optional GDrive / rclone configs go under `/tmp/.secrets/rclone.conf` when used
as a weight mirror — still not committed here.

## GitHub Secrets (if you automate later)

Suggested names (no values in this repo):

- `HF_TOKEN`
- `LLM_API_KEY`
- `CLOUDFLARE_TUNNEL_TOKEN_MOLAB_LLM`
