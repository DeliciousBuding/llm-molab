# Ops plan — single Blackwell 96GB

最后更新：2026-07-19 02:45

## Target

- GPU: NVIDIA RTX PRO 6000 Blackwell Server Edition, 96GB, SM 12.0
- Model: official FP8 `Qwen/Qwen3.6-35B-A3B-FP8`
- Engine: SGLang first, vLLM control later
- Context default: 128K server max; everyday prompts 8K–64K
- Ingress: temporary named tunnel `llm.vectorcontrol.tech` → `127.0.0.1:8000`

## Why not tp-size 8

Official HF samples use multi-GPU `tp-size 8`. This deployment is **one GPU** —
omit tensor parallel flags (default TP=1).

## Phases

0. Layout + HF download + SGLang venv  
1. Baseline 32K, no MTP  
2. MTP only  
3. 128K + chunked prefill  
4. FP8 KV quality A/B  
5. cloudflared + public smoke  
6. Optional vLLM on :8001  

## Paths on sandbox

```text
/marimo/llm-lab/          scripts, venvs, logs
/marimo/models/...        HF weights
/marimo/work/llm-molab/   this repo clone
/tmp/.secrets/            runtime secrets only
```

## Tear-down

1. Stop cloudflared + sglang  
2. Delete tunnel + DNS `llm`  
3. Wipe `/tmp/.secrets`  
4. Keep `/marimo/models` if you want faster relaunch  
