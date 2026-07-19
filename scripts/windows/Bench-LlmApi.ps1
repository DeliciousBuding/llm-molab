<#
.SYNOPSIS
  Run scripts/20_bench.py against public or local endpoint from Windows host.
#>
[CmdletBinding()]
param(
  [string]$Profile = "fast",
  [string]$BaseUrl = "https://llm.vectorcontrol.tech/v1",
  [string]$Model = "Qwen3.6-35B-A3B-FP8",
  [string]$OutDir = "",
  [int]$Repeats = 3,
  [switch]$SkipS7
)

$ErrorActionPreference = "Stop"
$repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$benchPy = Join-Path $repo "scripts\20_bench.py"
if (-not (Test-Path $benchPy)) { throw "missing $benchPy" }

$envFile = Join-Path $env:USERPROFILE ".config\server-secrets\llm-molab\llm.env"
$line = Get-Content $envFile | Where-Object { $_ -match '^\s*LLM_API_KEY=' } | Select-Object -First 1
if (-not $line) { throw "LLM_API_KEY missing" }
$key = ($line -split '=', 2)[1].Trim()

if (-not $OutDir) {
  $OutDir = Join-Path $env:TEMP "llm-molab-bench"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$env:OPENAI_BASE_URL = $BaseUrl
$env:OPENAI_API_KEY = $key
$env:LLM_API_KEY = $key
$env:MODEL_ID = $Model
$env:SERVE_MODE = $Profile

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $py) { throw "python not on PATH" }

$args = @($benchPy, "--profile", $Profile, "--base", $BaseUrl, "--model", $Model, "--out", $OutDir, "--repeats", "$Repeats")
if ($SkipS7) { $args += "--skip-s7" }

Write-Host "bench -> $($py.Source) $($args -join ' ')"
& $py.Source @args
Write-Host "out_dir=$OutDir"
