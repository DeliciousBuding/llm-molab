<#
.SYNOPSIS
  Public/local smoke for llm.vectorcontrol.tech
#>
[CmdletBinding()]
param(
  [string]$BaseUrl = "https://llm.vectorcontrol.tech/v1",
  [string]$Model = "Qwen3.6-35B-A3B-FP8"
)

$ErrorActionPreference = "Stop"
$envFile = Join-Path $env:USERPROFILE ".config\server-secrets\llm-molab\llm.env"
if (-not (Test-Path $envFile)) { throw "missing $envFile" }
$line = Get-Content $envFile | Where-Object { $_ -match '^\s*LLM_API_KEY=' } | Select-Object -First 1
if (-not $line) { throw "LLM_API_KEY not found in $envFile" }
$key = ($line -split '=', 2)[1].Trim()

$headers = @{ Authorization = "Bearer $key"; "Content-Type" = "application/json" }

Write-Host "=== models $BaseUrl ==="
$models = Invoke-RestMethod -Uri "$BaseUrl/models" -Headers $headers -TimeoutSec 30
$models | ConvertTo-Json -Depth 5

Write-Host "=== chat (thinking off) ==="
$body = @{
  model = $Model
  messages = @(@{ role = "user"; content = "用一句话中文介绍你自己。" })
  max_tokens = 128
  temperature = 0.6
  chat_template_kwargs = @{ enable_thinking = $false }
} | ConvertTo-Json -Depth 6

$r = Invoke-RestMethod -Uri "$BaseUrl/chat/completions" -Headers $headers -Method Post -Body $body -TimeoutSec 180
"finish=$($r.choices[0].finish_reason) completion_tokens=$($r.usage.completion_tokens)"
$r.choices[0].message.content
Write-Host "smoke_ok"
