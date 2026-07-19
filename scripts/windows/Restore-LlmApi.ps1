<#
.SYNOPSIS
  Inject secrets and submit package-first restore job with a serve profile.

.PARAMETER Account
  molab account

.PARAMETER Profile
  baseline | fast | long  (default fast)

.PARAMETER SkipWait
  Do not wait for job completion
#>
[CmdletBinding()]
param(
  [string]$Account = "notebook2",
  [ValidateSet("baseline", "fast", "long")]
  [string]$Profile = "fast",
  [switch]$SkipWait,
  [int]$JobTimeoutMinutes = 50
)

$ErrorActionPreference = "Stop"
$Sec = Join-Path $env:USERPROFILE ".config\server-secrets"
$llmEnv = Join-Path $Sec "llm-molab\llm.env"
$hfEnv = Join-Path $Sec "huggingface\token-download.env"
$tunnel = Join-Path $Sec "cloudflare\tunnel-molab-llm-tmp.token"

foreach ($p in @($llmEnv, $hfEnv, $tunnel)) {
  if (-not (Test-Path $p)) { throw "missing secret file: $p" }
}

Write-Host "restore account=$Account profile=$Profile"

# Doctor gate (soft): warn only
$doc = molab doctor $Account 2>&1 | Out-String
if ($doc -notmatch 'ready_for_exec"\s*:\s*true' -and $doc -notmatch 'ready_for_exec.: true') {
  Write-Warning "account may not be ready; prefer Wait-MolabReady.ps1 first"
}

molab fs mkdir $Account /tmp/.secrets | Out-Null
molab fs put $Account $llmEnv /tmp/.secrets/llm.env | Out-Null
molab fs put $Account $hfEnv /tmp/.secrets/hf.env | Out-Null
molab fs put $Account $tunnel /tmp/.secrets/tunnel.token | Out-Null
Write-Host "secrets_injected"

$jobPy = Join-Path $env:TEMP "llm-restore-$Profile.py"
$profileLiteral = $Profile
@"
import subprocess, sys
profile = "$profileLiteral"
script = r'''
set -e
export SERVE_PROFILE={profile}
if [ ! -d /marimo/work/llm-molab/.git ]; then
  git clone --depth 1 https://github.com/DeliciousBuding/llm-molab.git /marimo/work/llm-molab
fi
cd /marimo/work/llm-molab
git fetch origin
git reset --hard origin/main
chmod +x scripts/*.sh || true
sed -i 's/\r$//' /tmp/.secrets/* || true
# force profile even if state/serve.env survived with old values
bash scripts/16_apply_profile.sh {profile} || true
bash scripts/11_restore.sh
'''.format(profile=profile)
subprocess.check_call(["bash", "-lc", script])
"@ | Set-Content -Path $jobPy -Encoding utf8

$submit = molab job submit $Account --name "restore-$Profile" -f $jobPy 2>&1 | Out-String
Write-Host $submit
if ($submit -match '"job_id"\s*:\s*"([^"]+)"') {
  $jobId = $Matches[1]
} elseif ($submit -match 'job_id["''\s:]+([0-9a-fA-F-]+)') {
  $jobId = $Matches[1]
} else {
  throw "could not parse job_id from submit output"
}
Write-Host "job_id=$jobId"

if (-not $SkipWait) {
  molab job wait $Account $jobId --timeout "${JobTimeoutMinutes}m"
  Write-Host "job_done $jobId"
}

# write operator status (no secrets)
$status = @"
# llm-molab live (operator notes, no secrets)
last_restore=$(Get-Date -Format 'yyyy-MM-ddTHH:mmZ')
account=$Account
profile=$Profile
job_id=$jobId
public=https://llm.vectorcontrol.tech/v1
model_id=Qwen3.6-35B-A3B-FP8
repo=https://github.com/DeliciousBuding/llm-molab
note=restored via Restore-LlmApi.ps1; key in server-secrets/llm-molab/llm.env
"@
$statusPath = Join-Path $Sec "llm-molab\status.txt"
Set-Content -Path $statusPath -Value $status -Encoding utf8
Write-Host "status_written $statusPath"
Write-Host "next: .\scripts\windows\Smoke-LlmApi.ps1 ; .\scripts\windows\Bench-LlmApi.ps1 -Profile $Profile"
