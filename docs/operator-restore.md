# Operator restore after 410 / restart

最后更新：2026-07-19 16:40

## 心智模型

| 事件 | 权重/venv | `/tmp/.secrets` | CF 隧道 DNS | 本机 secrets |
|------|-----------|-----------------|-------------|--------------|
| 只杀 vllm/cloudflared 进程 | 仍在 | 若未重启沙盒仍在 | 在 | 在 |
| 同 sandbox 短暂断连后恢复 | 通常在 | 可能在 | 在 | 在 |
| **HTTP 410 remint（新 sb-）** | **常丢** | **没了** | 在 | 在 |
| `runtime stop --apply` | 远端未必杀；本机 lease 清 | — | 在 | 在 |

详解见 [persistence.md](persistence.md)。Profile 见 [tuning-matrix.md](tuning-matrix.md)。

## 本机一键（推荐）

仓库内 Windows 脚本（不进容器）：

```powershell
cd D:\Code\llm\llm-molab

# 1) 等 sandbox ready（不 thrash ensure）
.\scripts\windows\Wait-MolabReady.ps1 -Account notebook2 -TimeoutMinutes 20

# 2) 注入 secrets + restore（默认 SERVE_PROFILE=fast）
.\scripts\windows\Restore-LlmApi.ps1 -Account notebook2 -Profile fast

# 3) 公网 bench
.\scripts\windows\Bench-LlmApi.ps1 -Profile fast

# 4) 可选：公网冒烟
.\scripts\windows\Smoke-LlmApi.ps1
```

## PowerShell 手写（410 后）

```powershell
$Account = "notebook2"
$Sec = "$env:USERPROFILE\.config\server-secrets"
$Profile = "fast"   # baseline | fast | long

molab ensure $Account
molab runtime wait $Account --timeout 12m
molab doctor $Account   # ready_for_exec + gpu_ready

molab fs mkdir $Account /tmp/.secrets
molab fs put $Account "$Sec\llm-molab\llm.env" /tmp/.secrets/llm.env
molab fs put $Account "$Sec\huggingface\token-download.env" /tmp/.secrets/hf.env
molab fs put $Account "$Sec\cloudflare\tunnel-molab-llm-tmp.token" /tmp/.secrets/tunnel.token

@'
import os, subprocess, sys
profile = os.environ.get("SERVE_PROFILE", "fast")
subprocess.check_call(["bash","-lc",f"""
set -e
export SERVE_PROFILE={profile}
if [ ! -d /marimo/work/llm-molab/.git ]; then
  git clone --depth 1 https://github.com/DeliciousBuding/llm-molab.git /marimo/work/llm-molab
fi
cd /marimo/work/llm-molab && git fetch origin && git reset --hard origin/main
chmod +x scripts/*.sh
sed -i 's/\\r$//' /tmp/.secrets/* || true
bash scripts/11_restore.sh
"""])
'@ | Set-Content $env:TEMP\llm-restore-job.py -Encoding utf8

# job env is not automatically forwarded; bake profile into the script or:
molab job submit $Account --name restore-api -f $env:TEMP\llm-restore-job.py
molab job wait $Account <id> --timeout 50m
```

更干净：直接用 `Restore-LlmApi.ps1`（已把 `SERVE_PROFILE` 写进 job body）。

## 同 sandbox 热恢复 / 切 profile

```bash
# 模型还在 package 时
export SERVE_PROFILE=fast
bash /marimo/work/llm-molab/scripts/16_apply_profile.sh fast
bash /marimo/work/llm-molab/scripts/05b_serve_vllm.sh
bash /marimo/work/llm-molab/scripts/10_wait_api.sh
bash /marimo/work/llm-molab/scripts/07_cloudflared.sh
python3 /marimo/work/llm-molab/scripts/20_bench.py --profile fast
bash /marimo/work/llm-molab/scripts/17_watchdog.sh once
```

## Profiles

| Name | ctx | mem | 备注 |
|------|-----|-----|------|
| baseline | 32K | 0.80 | remint 保命 |
| **fast** | 32K | **0.88** | 日常默认（推荐） |
| long | 128K | 0.88 + FP8 KV | 需 A/B |

## 验收

```bash
export OPENAI_BASE_URL=https://llm.vectorcontrol.tech/v1
export OPENAI_API_KEY=...   # server-secrets/llm-molab/llm.env
export MODEL_ID=Qwen3.6-35B-A3B-FP8

curl -sS "$OPENAI_BASE_URL/models" -H "Authorization: Bearer $OPENAI_API_KEY"
curl -sS "$OPENAI_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen3.6-35B-A3B-FP8","messages":[{"role":"user","content":"test"}],"max_tokens":64,"chat_template_kwargs":{"enable_thinking":false}}'
```

Cherry：Base `https://llm.vectorcontrol.tech/v1`，model `Qwen3.6-35B-A3B-FP8`，能加 body 则 `enable_thinking=false`。

## 不要做的事

- 410 / health timeout 时连续 `ensure` thrash  
- 把 API key 写进 `/marimo/llm-lab/state/serve.env`  
- 假设 DiffAudit 还在 ⇒ 模型也还在  
- 用 `runtime stop` 当“优雅重启服务”（它只清本机 lease）  
- proxy 2261 挂了还狂 ensure（先起 resin-local）  
