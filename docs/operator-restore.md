# Operator: restore API after molab notebook restart (Windows)

最后更新：2026-07-19 03:30

## Prerequisites

- `molab` on PATH
- secrets under `~/.config/server-secrets/`
- public repo: https://github.com/DeliciousBuding/llm-molab
- Cloudflare tunnel `molab-llm-tmp` + DNS `llm.vectorcontrol.tech` already created

## One-shot (PowerShell)

```powershell
$Account = "notebook2"
$Sec = "$env:USERPROFILE\.config\server-secrets"

molab ensure $Account
molab doctor $Account   # need ready_for_exec + gpu_ready

# re-inject runtime secrets (/tmp only)
molab fs mkdir $Account /tmp/.secrets
molab fs put $Account "$Sec\llm-molab\llm.env" /tmp/.secrets/llm.env
molab fs put $Account "$Sec\huggingface\token-download.env" /tmp/.secrets/hf.env
molab fs put $Account "$Sec\cloudflare\tunnel-molab-llm-tmp.token" /tmp/.secrets/tunnel.token
molab ssh $Account -c "chmod 700 /tmp/.secrets && chmod 600 /tmp/.secrets/*; sed -i 's/\r$//' /tmp/.secrets/*"

# ensure repo + restore (skips model/venv if durable /marimo intact)
molab ssh $Account -c @"
set -e
if [ ! -d /marimo/work/llm-molab/.git ]; then
  git clone --depth 1 https://github.com/DeliciousBuding/llm-molab.git /marimo/work/llm-molab
else
  cd /marimo/work/llm-molab && git fetch origin && git reset --hard origin/main
fi
chmod +x /marimo/work/llm-molab/scripts/*.sh
# prefer durable baseline knobs for first bring-up
mkdir -p /marimo/llm-lab/state
cp -n /marimo/work/llm-molab/configs/serve.env.example /marimo/llm-lab/state/serve.env || true
bash /marimo/work/llm-molab/scripts/11_restore.sh
"@
```

Or submit as job (preferred for long install/load):

```powershell
# job_restore.py calls scripts/11_restore.sh
molab job submit notebook2 --name restore-api -f .\job_restore.py
molab job wait notebook2 <id> --timeout 45m
```

## After API is up

```bash
# local
curl -s http://127.0.0.1:8000/v1/models -H "Authorization: Bearer $LLM_API_KEY"
# public
curl -s https://llm.vectorcontrol.tech/v1/models -H "Authorization: Bearer $LLM_API_KEY"
```

Client:

```text
OPENAI_BASE_URL=https://llm.vectorcontrol.tech/v1
OPENAI_API_KEY=<from llm.env>
```

## If molab returns 403 / Gateway Timeout

1. Stop thrashing: `molab daemon stop --accounts notebook2` (if running)
2. Browser login + cookie export (see `molab auth-recover notebook2`)
3. `molab import notebook2 --file <cookies>`
4. `molab refresh notebook2 --force`
5. `molab ensure notebook2`

## Safer first-boot knobs

Use `SERVE_MODE=baseline`, `CONTEXT_LENGTH=32768`, `MEM_FRACTION_STATIC=0.80`, `ENABLE_MTP=0`.
Only after `/v1/models` is healthy, raise context toward 128K and re-enable MTP.

## Rotate API key if it leaked in process lists / logs

Regenerate `LLM_API_KEY` in `server-secrets/llm-molab/llm.env`, re-inject `/tmp/.secrets/llm.env`, restart serve.
