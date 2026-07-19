# Client cheat-sheet (Cherry / curl / OpenAI SDK)

最后更新：2026-07-19 16:40

## Endpoint

| | |
|--|--|
| Base URL | `https://llm.vectorcontrol.tech/v1` |
| Model id | `Qwen3.6-35B-A3B-FP8` |
| Auth | `Authorization: Bearer <LLM_API_KEY>` |
| Key store | `~/.config/server-secrets/llm-molab/llm.env` |

## Cherry Studio

1. Provider type: OpenAI Compatible  
2. API Host: `https://llm.vectorcontrol.tech`（有的客户端要带 `/v1`，以能列出 models 为准）  
3. API Key: 同上  
4. Model: `Qwen3.6-35B-A3B-FP8`  
5. 若支持自定义 body / extra params：

```json
{
  "chat_template_kwargs": { "enable_thinking": false }
}
```

Qwen3.6 默认 thinking 会吃掉小 `max_tokens`，短聊务必关。

## curl

```bash
export OPENAI_BASE_URL=https://llm.vectorcontrol.tech/v1
export OPENAI_API_KEY=...

curl -sS "$OPENAI_BASE_URL/models" -H "Authorization: Bearer $OPENAI_API_KEY"

curl -sS "$OPENAI_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3.6-35B-A3B-FP8",
    "messages": [{"role":"user","content":"test"}],
    "max_tokens": 64,
    "chat_template_kwargs": {"enable_thinking": false}
  }'
```

## Profiles (server)

| 客户端场景 | 建议服务端 profile | 客户端 thinking |
|------------|-------------------|-----------------|
| 日常闲聊 | `fast` | off |
| 深推理 | `fast` 或 `baseline` | on + 大 max_tokens |
| 长文档 | `long` | off/on 按任务 |

本机切服务端：

```powershell
.\scripts\windows\Restore-LlmApi.ps1 -Account notebook2 -Profile fast
# 同 sb 热切：
# molab ssh notebook2 -c "bash /marimo/work/llm-molab/scripts/18_switch_profile.sh fast"
```

## Errors

| 现象 | 含义 | 动作 |
|------|------|------|
| CF 1033 / HTTP 530 | tunnel 或 origin 挂了 | `Wait-MolabReady` + `Restore-LlmApi` |
| 401 | key 错 | 查 `llm.env` |
| 空/thinking 废话 | thinking 开着 + max_tokens 小 | `enable_thinking=false` |
| 超时 | 冷启动 compile ~3–4min | 等 `10_wait_api` / job 完成 |
