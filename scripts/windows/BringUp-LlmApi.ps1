<#
.SYNOPSIS
  One-shot operator path: wait ready -> restore profile -> smoke -> optional bench.
#>
[CmdletBinding()]
param(
  [string]$Account = "notebook2",
  [ValidateSet("baseline", "fast", "long")]
  [string]$Profile = "fast",
  [switch]$RunBench,
  [int]$WaitMinutes = 20
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot

Write-Host "== 1 wait ready =="
& (Join-Path $here "Wait-MolabReady.ps1") -Account $Account -TimeoutMinutes $WaitMinutes -EnsureOnce
if ($LASTEXITCODE -ne 0) { throw "account not ready" }

Write-Host "== 2 restore profile=$Profile =="
& (Join-Path $here "Restore-LlmApi.ps1") -Account $Account -Profile $Profile

Write-Host "== 3 smoke =="
# give tunnel a few seconds
Start-Sleep -Seconds 5
& (Join-Path $here "Smoke-LlmApi.ps1")

if ($RunBench) {
  Write-Host "== 4 bench =="
  & (Join-Path $here "Bench-LlmApi.ps1") -Profile $Profile
}

Write-Host "bringup_ok account=$Account profile=$Profile"
