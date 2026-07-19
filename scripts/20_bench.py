#!/usr/bin/env python3
"""Minimal OpenAI-compatible bench for llm-molab profiles.

Scenarios:
  S1 short chat
  S2 medium answer
  S5 prefix reuse (same system)
  S7 concurrency (1/4/8)

Usage (inside sandbox or local with tunnel):
  export OPENAI_BASE_URL=http://127.0.0.1:8000/v1
  export OPENAI_API_KEY=...
  export MODEL_ID=Qwen3.6-35B-A3B-FP8
  python3 scripts/20_bench.py --profile baseline --out /marimo/llm-lab/bench
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import statistics
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()


def chat(
    base: str,
    key: str,
    model: str,
    messages: list[dict[str, str]],
    max_tokens: int,
    thinking: bool,
    timeout: float = 180.0,
) -> dict[str, Any]:
    body: dict[str, Any] = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": 0.6,
        "stream": False,
        "chat_template_kwargs": {"enable_thinking": thinking},
    }
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        base.rstrip("/") + "/chat/completions",
        data=data,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            code = resp.status
    except urllib.error.HTTPError as e:
        raw = e.read() if e.fp else b""
        code = e.code
        e2e = time.perf_counter() - t0
        return {
            "ok": False,
            "http": code,
            "e2e_s": e2e,
            "error": raw[:300].decode("utf-8", "replace"),
        }
    except Exception as e:  # noqa: BLE001
        e2e = time.perf_counter() - t0
        return {"ok": False, "http": 0, "e2e_s": e2e, "error": str(e)}

    e2e = time.perf_counter() - t0
    try:
        payload = json.loads(raw.decode("utf-8"))
    except json.JSONDecodeError:
        return {
            "ok": False,
            "http": code,
            "e2e_s": e2e,
            "error": "bad_json",
            "raw": raw[:200].decode("utf-8", "replace"),
        }

    usage = payload.get("usage") or {}
    completion = int(usage.get("completion_tokens") or 0)
    prompt = int(usage.get("prompt_tokens") or 0)
    content = ""
    try:
        content = payload["choices"][0]["message"].get("content") or ""
    except Exception:  # noqa: BLE001
        content = ""
    # non-stream TTFT is not true first-token; approximate with e2e for short gens
    tok_s = (completion / e2e) if e2e > 0 and completion > 0 else 0.0
    return {
        "ok": code == 200 and completion > 0,
        "http": code,
        "e2e_s": round(e2e, 4),
        "prompt_tokens": prompt,
        "completion_tokens": completion,
        "tok_s": round(tok_s, 3),
        "chars": len(content),
        "finish": (payload.get("choices") or [{}])[0].get("finish_reason"),
    }


def summarize(rows: list[dict[str, Any]]) -> dict[str, Any]:
    ok = [r for r in rows if r.get("ok")]
    e2e = [r["e2e_s"] for r in ok]
    tok = [r["tok_s"] for r in ok]
    return {
        "n": len(rows),
        "ok": len(ok),
        "error_rate": round(1 - (len(ok) / len(rows) if rows else 0), 4),
        "e2e_p50": round(statistics.median(e2e), 4) if e2e else None,
        "e2e_mean": round(statistics.mean(e2e), 4) if e2e else None,
        "tok_s_p50": round(statistics.median(tok), 3) if tok else None,
        "tok_s_mean": round(statistics.mean(tok), 3) if tok else None,
    }


def run_s1(base: str, key: str, model: str, n: int) -> dict[str, Any]:
    rows = []
    for _ in range(n):
        rows.append(
            chat(
                base,
                key,
                model,
                [{"role": "user", "content": "Reply with exactly: pong"}],
                max_tokens=32,
                thinking=False,
            )
        )
    return {"scenario": "S1_short", "summary": summarize(rows), "rows": rows}


def run_s2(base: str, key: str, model: str, n: int) -> dict[str, Any]:
    prompt = (
        "用中文写一段约120字的说明：什么是 continuous batching，"
        "以及它如何提高 LLM 服务吞吐。不要输出思考过程。"
    )
    rows = []
    for _ in range(n):
        rows.append(
            chat(
                base,
                key,
                model,
                [{"role": "user", "content": prompt}],
                max_tokens=256,
                thinking=False,
            )
        )
    return {"scenario": "S2_medium", "summary": summarize(rows), "rows": rows}


def run_s5(base: str, key: str, model: str, n: int) -> dict[str, Any]:
    system = (
        "你是稳定的中文技术助手。回答简洁、准确、可执行。"
        "固定系统提示用于测试 prefix cache。" * 20
    )
    rows = []
    for i in range(n):
        rows.append(
            chat(
                base,
                key,
                model,
                [
                    {"role": "system", "content": system},
                    {"role": "user", "content": f"第{i+1}问：用一句话解释 KV cache。"},
                ],
                max_tokens=64,
                thinking=False,
            )
        )
    return {"scenario": "S5_prefix", "summary": summarize(rows), "rows": rows}


def run_s7(base: str, key: str, model: str, conc: int, n_each: int) -> dict[str, Any]:
    def one(i: int) -> dict[str, Any]:
        return chat(
            base,
            key,
            model,
            [{"role": "user", "content": f"并发测试#{i}：返回一个四字成语即可。"}],
            max_tokens=32,
            thinking=False,
            timeout=300.0,
        )

    jobs = list(range(conc * n_each))
    t0 = time.perf_counter()
    rows: list[dict[str, Any]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=conc) as ex:
        futs = [ex.submit(one, i) for i in jobs]
        for f in concurrent.futures.as_completed(futs):
            rows.append(f.result())
    wall = time.perf_counter() - t0
    total_completion = sum(int(r.get("completion_tokens") or 0) for r in rows if r.get("ok"))
    summary = summarize(rows)
    summary["wall_s"] = round(wall, 4)
    summary["agg_tok_s"] = round(total_completion / wall, 3) if wall > 0 else 0.0
    summary["concurrency"] = conc
    return {"scenario": f"S7_conc_{conc}", "summary": summary, "rows": rows}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", default=env("SERVE_MODE", "unknown"))
    ap.add_argument("--base", default=env("OPENAI_BASE_URL", "http://127.0.0.1:8000/v1"))
    ap.add_argument("--key", default=env("OPENAI_API_KEY") or env("LLM_API_KEY"))
    ap.add_argument("--model", default=env("MODEL_ID", "Qwen3.6-35B-A3B-FP8"))
    ap.add_argument("--out", default="/marimo/llm-lab/bench")
    ap.add_argument("--repeats", type=int, default=3)
    ap.add_argument("--skip-s7", action="store_true")
    args = ap.parse_args()
    if not args.key:
        raise SystemExit("need OPENAI_API_KEY or LLM_API_KEY")

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    report: dict[str, Any] = {
        "schema": "llm-molab.bench/v1",
        "profile": args.profile,
        "base": args.base,
        "model": args.model,
        "ts": stamp,
        "scenarios": [],
    }

    print(f"bench profile={args.profile} base={args.base} model={args.model}")
    for fn in (run_s1, run_s2, run_s5):
        r = fn(args.base, args.key, args.model, args.repeats)
        report["scenarios"].append(r)
        print(r["scenario"], json.dumps(r["summary"], ensure_ascii=False))

    if not args.skip_s7:
        for c in (1, 4, 8):
            r = run_s7(args.base, args.key, args.model, conc=c, n_each=2)
            report["scenarios"].append(r)
            print(r["scenario"], json.dumps(r["summary"], ensure_ascii=False))

    path = out_dir / f"bench_{args.profile}_{stamp}.json"
    path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("wrote", path)
    # compact table
    print("--- table ---")
    for s in report["scenarios"]:
        sm = s["summary"]
        print(
            f"{s['scenario']:12} ok={sm['ok']}/{sm['n']} "
            f"e2e_p50={sm.get('e2e_p50')} tok_s_p50={sm.get('tok_s_p50')} "
            f"agg={sm.get('agg_tok_s', '-')}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
