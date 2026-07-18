#!/usr/bin/env bash
# Probe /marimo package occupancy and write a stamp for remint tests.
set -euo pipefail

cmd="${1:-probe}"
STAMP=/marimo/.llm_package_stamp
MARKER=/marimo/.llm_persist_probe

case "$cmd" in
  probe)
    date -u +%Y-%m-%dT%H:%M:%SZ | tee "$MARKER"
    echo "sandbox_probe $(hostname) $(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$STAMP"
    echo "=== df ==="
    df -h /marimo / 2>/dev/null || true
    echo "=== du /marimo ==="
    du -sh /marimo/* 2>/dev/null | sort -h || true
    echo "=== key paths ==="
    for p in \
      /marimo/models/Qwen3.6-35B-A3B-FP8/config.json \
      /marimo/llm-lab/.venv-vllm/bin/python \
      /marimo/bin/cloudflared \
      /marimo/llm-lab/cf/cloudflared \
      /marimo/DiffAudit-Research-Server \
      /marimo/work/llm-molab \
      "$STAMP"
    do
      if [[ -e "$p" ]]; then
        if [[ -d "$p" ]]; then
          echo "PRESENT_DIR $p $(du -sh "$p" 2>/dev/null | awk '{print $1}')"
        else
          echo "PRESENT_FILE $p $(stat -c%s "$p" 2>/dev/null || wc -c <"$p") bytes"
        fi
      else
        echo "ABSENT $p"
      fi
    done
    if [[ -f /marimo/models/Qwen3.6-35B-A3B-FP8/config.json ]]; then
      echo "PACKAGE_POLICY=keep_models_under_/marimo (quota permitting)"
      echo "model_size=$(du -sh /marimo/models/Qwen3.6-35B-A3B-FP8 | awk '{print $1}')"
    fi
    ;;
  verify)
    echo "=== post-remint verify ==="
    if [[ -f "$STAMP" ]]; then
      echo "STAMP_SURVIVED $(cat "$STAMP")"
    else
      echo "STAMP_LOST (package did not keep stamp — small files may still sync on next write)"
    fi
    if [[ -f /marimo/models/Qwen3.6-35B-A3B-FP8/config.json ]]; then
      echo "MODELS_SURVIVED $(du -sh /marimo/models/Qwen3.6-35B-A3B-FP8 | awk '{print $1}')"
    else
      echo "MODELS_LOST (need HF ensure; or quota too small for 35G package)"
    fi
    if [[ -x /marimo/llm-lab/.venv-vllm/bin/python ]]; then
      echo "VENV_SURVIVED"
    else
      echo "VENV_LOST"
    fi
    if [[ -x /marimo/bin/cloudflared || -x /marimo/llm-lab/cf/cloudflared ]]; then
      echo "CLOUDFLARED_SURVIVED"
    else
      echo "CLOUDFLARED_LOST"
    fi
    if [[ -d /marimo/DiffAudit-Research-Server ]]; then
      echo "DIFFAUDIT_SURVIVED (package channel works)"
    fi
    bash "$0" probe
    ;;
  *)
    echo "usage: $0 probe|verify" >&2
    exit 2
    ;;
esac
