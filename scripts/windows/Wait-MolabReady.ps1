<#
.SYNOPSIS
  Wait until molab account is ready_for_exec + gpu_ready without thrashing ensure.

.PARAMETER Account
  molab account name (notebook1 / notebook2)

.PARAMETER TimeoutMinutes
  Max wait

.PARAMETER EnsureOnce
  If set, run a single `molab ensure` only when there is no usable lease/alive.
#>
[CmdletBinding()]
param(
  [string]$Account = "notebook2",
  [int]$TimeoutMinutes = 20,
  [switch]$EnsureOnce
)

$ErrorActionPreference = "Continue"
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)

function Get-DoctorText {
  param([string]$Acc)
  molab doctor $Acc 2>&1 | Out-String
}

function Test-Ready {
  param([string]$Text)
  return ($Text -match 'ready_for_exec"\s*:\s*true' -or $Text -match 'ready_for_exec.: true') `
    -and ($Text -match 'gpu_ready"\s*:\s*true' -or $Text -match 'gpu_ready.: true') `
    -and ($Text -match 'alive"\s*:\s*true' -or $Text -match 'alive.: true')
}

Write-Host "wait_ready account=$Account timeout_min=$TimeoutMinutes"
$didEnsure = $false

while ((Get-Date) -lt $deadline) {
  $doc = Get-DoctorText -Acc $Account
  if (Test-Ready -Text $doc) {
    Write-Host "READY account=$Account"
    molab doctor $Account 2>&1 | Select-String -Pattern 'ready_for_exec|gpu_ready|alive|sandbox_id|notes'
    exit 0
  }

  if ($EnsureOnce -and -not $didEnsure) {
    if ($doc -match 'TOKEN_INVALID' -or $doc -match 'no sandbox' -or $doc -match 'SANDBOX_410' -or $doc -match 'blocking_code') {
      Write-Host "ensure_once account=$Account"
      molab runtime stop $Account --apply 2>&1 | Out-Null
      molab ensure $Account 2>&1 | Out-Null
      $didEnsure = $true
    }
  }

  Write-Host ("{0:u} not_ready; runtime wait 2m..." -f (Get-Date).ToUniversalTime())
  molab runtime wait $Account --timeout 2m 2>&1 | Out-Null
}

Write-Host "TIMEOUT account=$Account not ready" -ForegroundColor Red
molab doctor $Account 2>&1 | Select-String -Pattern 'ready_for_exec|gpu_ready|alive|blocking|notes|sandbox_id'
exit 1
