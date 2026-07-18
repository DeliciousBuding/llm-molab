# Tuning matrix (single-variable)

最后更新：2026-07-19 02:45

Change **one** knob per restart. Record TTFT, decode tok/s, tool JSON success, OOM.

| Phase | Knob | Start | Candidates |
|-------|------|-------|------------|
| 0 | context | 32768 | — |
| 0 | mem-fraction-static | 0.80 | 0.84 / 0.88 / 0.90 |
| 1 | MTP steps | off | 1 / 2 / 3 |
| 2 | context | 131072 | 65536 if OOM |
| 2 | chunked-prefill-size | 8192 | 4096 / 16384 |
| 3 | kv-cache-dtype | default | `fp8_e4m3` |

## Prod candidate (after A/B)

See `scripts/06_serve_prod_candidate.sh`.

## Profiles (client)

| Name | thinking | max_tokens |
|------|----------|------------|
| fast | off | 2048–4096 |
| deep | on | 8192–16384 |
