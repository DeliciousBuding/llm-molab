# Operator restore after 410 / restart

最后更新：2026-07-19 04:00

## 心智模型

| 事件 | 权重/venv | `/tmp/.secrets` | CF 隧道 DNS | 本机 secrets |
|------|-----------|-----------------|-------------|--------------|
| 只杀 vllm/cloudflared 进程 | 仍在 | 若未重启沙盒仍在 | 在 | 在 |
| 同 sandbox 短暂断连后恢复 | 通常在 | 可能在 | 在 | 在 |
| **HTTP 410 remint（新 sb-）** | **没了** | **没了** | 在 | 在 |
| `runtime stop --apply` | 远端未必杀；本机 lease 清 | — | 在 | 在 |

详解见 [persistence.md](persistence.md)。

## PowerShell 一键（410 后）

```powershell
$Account = "notebook2"
$Sec = "$env:USERPROFILE\.config\server-secrets"

molab ensure $Account
molab runtime wait $Account --timeout 10m
molab doctor $Account   # ready_for_exec + gpu_ready

molab fs mkdir $Account /tmp/.secrets
molab fs put $Account "$Sec\llm-molab\llm.env" /tmp/.secrets/llm.env
molab fs put $Account "$Sec\huggingface\token-download.env" /tmp/.secrets/hf.env
molab fs put $Account "$Sec\cloudflare\tunnel-molab-llm-tmp.token" /tmp/.secrets/tunnel.token

# long path: download 35G + venv + serve — use job
@'
import subprocess, sys
subprocess.check_call(["bash","-lc","""
set -e
if [ ! -d /marimo/work/llm-molab/.git ]; then
  git clone --depth 1 https://github.com/DeliciousBuding/llm-molab.git /marimo/work/llm-molab
fi
cd /marimo/work/llm-molab && git fetch origin && git reset --hard origin/main
chmod +x scripts/*.sh
sed -i 's/\\r$//' /tmp/.secrets/* || true
bash scripts/11_restore.sh
"""])
'@ | Set-Content $env:TEMP\llm-restore-job.py -Encoding utf8

molab job submit $Account --name restore-api -f $env:TEMP\llm-restore-job.py
molab job wait $Account <id> --timeout 45m
```

## 同 sandbox 热恢复（模型还在）

```bash
bash /marimo/work/llm-molab/scripts/11_restore.sh
# 应看到 model_ok / venv_*_ok，只重启 serve + tunnel
```

## 验收

```bash
curl -sS https://llm.vectorcontrol.tech/v1/models \
  -H "Authorization: Bearer $LLM_API_KEY" | head
# model id 以 /v1/models 返回为准（路径或 served-model-name）
```

## 不要做的事

- 410 过程中连续 `ensure` thrash  
- 把 API key 写进 `/marimo/llm-lab/state/serve.env`  
- 假设 DiffAudit 还在 ⇒ 模型也还在（那是 notebook 包，不是算力盘）  
- 用 `runtime stop` 当“优雅重启服务”（它只清本机 lease）  
