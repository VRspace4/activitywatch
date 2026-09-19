# ActivityWatch watchdog — permanent. Restarts aw-qt if localhost:5600 is closed.
# Paths use %LOCALAPPDATA% only (per-user install). No machine-specific username.
#
# Expected install location after install.ps1:
#   %LOCALAPPDATA%\life-coach\aw-watchdog.ps1
# Scheduled task (current user): LifeCoach-ActivityWatch-Watchdog every 5 minutes.

$ErrorActionPreference = "Continue"
$lifeCoachDir = Join-Path $env:LOCALAPPDATA "life-coach"
$log = Join-Path $lifeCoachDir "aw-watchdog.log"
$awQt = Join-Path $env:LOCALAPPDATA "Programs\ActivityWatch\aw-qt.exe"

if (-not (Test-Path $lifeCoachDir)) {
  New-Item -ItemType Directory -Path $lifeCoachDir -Force | Out-Null
}

function Write-Log($msg) {
  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
  Add-Content -Path $log -Value $line -Encoding UTF8
  if ((Get-Item $log -ErrorAction SilentlyContinue).Length -gt 2MB) {
    Move-Item $log "$log.old" -Force -ErrorAction SilentlyContinue
  }
}

function Test-AwApi {
  try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:5600/api/0/info" -UseBasicParsing -TimeoutSec 3
    return ($r.StatusCode -eq 200)
  } catch { return $false }
}

if (Test-AwApi) { exit 0 }
Write-Log "API down; attempting restart"
Get-Process -Name "aw-qt","aw-server","aw-server-rust","aw-watcher-afk","aw-watcher-window","aw-watcher-input","aw-notify" -ErrorAction SilentlyContinue |
  Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
if (-not (Test-Path $awQt)) {
  Write-Log "MISSING $awQt"
  exit 1
}
Start-Process -FilePath $awQt -WorkingDirectory (Split-Path $awQt)
$ok = $false
for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Seconds 2
  if (Test-AwApi) { $ok = $true; break }
}
if ($ok) { Write-Log "API back up" } else { Write-Log "FAIL still down after restart" }
