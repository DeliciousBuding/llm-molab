# Tuning matrix + profiles (single-variable)

最后更新：2026-07-19 16:15

## Profiles (`configs/serve.<name>.env`)

| Profile | ctx | mem | KV | max-num-seqs | MTP | 用途 |
|---------|-----|-----|----|--------------|-----|------|
| `baseline` | 32K | 0.80 | default | default | off | remint 后保命 |
| `fast` | 32K | **0.88** | default | **32** | off | 日常 Cherry / 更高并发 |
| `long` | **128K** | 0.88 | **fp8** | 16 | off | 长上下文候选（需 A/B） |

```bash
bash scripts/16_apply_profile.sh fast
bash scripts/05b_serve_vllm.sh
bash scripts/10_wait_api.sh
python3 scripts/20_bench.py --profile fast
```

## Single-variable knobs

| Phase | Knob | Start | Candidates |
|-------|------|-------|------------|
| A | mem-fraction / gpu-memory-utilization | 0.80 | **0.88** / 0.90 |
| A | max-num-seqs | default | 16 / 32 / 64 |
| B | MTP (SGLang NEXTN / vLLM if supported) | off | steps 1→2→3 |
| C | kv-cache-dtype | default | `fp8` |
| C | context | 32768 | 65536 / 131072 |
| C | chunked-prefill-size | 8192 | 4096 / 16384 |

**一次只改一个旋钮。** 记录 TTFT/e2e、decode tok/s、并发 agg tok/s、OOM、JSON 成功率。

## Bench (`scripts/20_bench.py`)

| ID | 内容 |
|----|------|
| S1 | 短答 max_tokens=32，thinking off |
| S2 | 中文中答 max_tokens=256 |
| S5 | 长 system 前缀复用 |
| S7 | 并发 1/4/8 |

指标：`e2e_p50`、`tok_s_p50`、`agg_tok_s`、`error_rate`。  
结果写 `/marimo/llm-lab/bench/bench_<profile>_<ts>.json`。

## Client profiles

| Name | thinking | max_tokens |
|------|----------|------------|
| fast | off (`chat_template_kwargs.enable_thinking=false`) | 1024–4096 |
| deep | on | 8192–16384 |

## Promote rules

1. 不起服 / OOM → 回退上一档  
2. S1–S2 `tok_s` 不低于 baseline 的 95%（开 MTP 应明显高于）  
3. S7@8 的 error_rate=0 且 P95 可接受  
4. `long` 额外：S6 长文 3 次 smoke + 质量抽检  
5. remint 后 `11_restore` 仍可恢复  

## Watchdog

同 sandbox 热恢复（不 remint）：

```bash
bash scripts/17_watchdog.sh once
# or: bash scripts/17_watchdog.sh loop 60
```
