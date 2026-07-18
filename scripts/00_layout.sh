#!/usr/bin/env bash
# Create durable dirs on molab sandbox.
set -euo pipefail

mkdir -p /marimo/llm-lab/{scripts,configs,logs,bench,cf,venvs}
mkdir -p /marimo/models
mkdir -p /marimo/work
mkdir -p /tmp/.secrets /tmp/hf-cache
chmod 700 /tmp/.secrets

echo "layout_ok"
df -h /marimo /tmp 2>/dev/null || true
nvidia-smi -L || true
