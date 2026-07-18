# Package-first persistence (有配额就塞)

最后更新：2026-07-19 04:20

## 原则（按你的要求）

1. **有配额 → 往 notebook package / `/marimo` 工作区塞**，remint 后优先从 package 恢复，保证效率。  
2. **权重、cloudflared、推理 venv、脚本** 全部落在 **固定 `/marimo/...` 路径**，禁止只放 `/tmp`。  
3. **密钥永远不进 package**（`/tmp/.secrets` + 本机 `server-secrets`）。  
4. remint 后：**有则 skip，缺则下/装**（幂等 ensure）。

官方：每 notebook 有 **limited persistent storage**（侧栏文件树，R2）。无公开 GB 数字；**实测以 `du` + remint 探针为准**。  
参考：[molab guide](https://docs.marimo.io/guides/molab/) · [announcing molab](https://marimo.io/blog/announcing-molab)

## 证据（本会话）

| 路径 | 跨 410 remint | 说明 |
|------|---------------|------|
| `/marimo/DiffAudit-Research-Server` (~341M) | **在** | package/workspace 同步层 |
| `/marimo/notebook.py` `pyproject.toml` | **在** | notebook 包 |
| `/marimo/models/Qwen…` (35G) | **曾不在** | 写在运行时盘或未进同步/超限；**策略改为强制写 `/marimo/models` + remint 探针** |
| `/tmp/.secrets` | **不在** | 预期 |

结论：DiffAudit 证明 **package 通道有效**。35G 该走 **同一 `/marimo` 树**；能否留下取决于 **配额与同步**，不是“别塞”。

## 固定布局（全部在 `/marimo`）

```text
/marimo/
  bin/cloudflared                 # 小，必进 package
  llm-molab/                      # 本仓 clone（或 work/llm-molab）
  llm-lab/
    state/serve.env               # 无密钥
    state/MANIFEST.json
    .venv-vllm/                   # 大：有配额则留；无则 ensure 重装
    logs/
  models/Qwen3.6-35B-A3B-FP8/     # 35G：有配额则留；ensure 续传
  DiffAudit-Research-Server/      # 已有
```

## 流程

```text
layout
  → ensure cloudflared → /marimo/bin/cloudflared
  → ensure model       → /marimo/models/...  (存在 config+safetensors 则 skip)
  → ensure venv        → /marimo/llm-lab/.venv-vllm
  → serve + tunnel
  → write MANIFEST + .llm_package_stamp
remint 后
  → 11_restore：stamp/manifest 命中则秒起；否则补下/补装
```

## 配额探针（必做一次）

```bash
bash scripts/15_probe_package_quota.sh
# 写小文件 + 统计 /marimo 占用
# remint 后再跑 15_probe_package_quota.sh verify
```

- **remint 后 models 仍在** → 全速 package 持久，日常只热起服  
- **remint 后 models 没了** → 配额/同步不够；仍写 `/marimo/models`（同 sb 热复用），冷恢复靠 HF 续传；或 rclone 冷备  

## 效率

| 场景 | 行为 |
|------|------|
| 同 sandbox 杀进程 | 不重下，只起服 |
| remint 且 35G 在 package | 不重下 |
| remint 且 35G 丢了 | HF 续传（比全量乱下好） |
| venv | import 成功 skip；失败重装 |

## 禁止 thrash

`runtime stop --apply` **只清本机 lease**。lease 不稳时 **不要**连续 ensure/stop，否则容易 410 连环 remint。  
探活超时：先 `runtime wait`，再操作。
