# ActivityWatch DB prune — keep last 60 days. Stops AW, deletes old events, VACUUM, restarts.
# Targets the Python aw-server peewee SQLite file under %LOCALAPPDATA%.
# Requires `python` on PATH. Paths use env vars only (no machine-specific username).
#
# Expected install location after install.ps1:
#   %LOCALAPPDATA%\life-coach\aw-prune.ps1
# Scheduled task (current user): LifeCoach-ActivityWatch-Prune monthly day 1 at 03:15.

$ErrorActionPreference = "Stop"
$lifeCoachDir = Join-Path $env:LOCALAPPDATA "life-coach"
$log = Join-Path $lifeCoachDir "aw-prune.log"
$awQt = Join-Path $env:LOCALAPPDATA "Programs\ActivityWatch\aw-qt.exe"
$db = Join-Path $env:LOCALAPPDATA "activitywatch\activitywatch\aw-server\peewee-sqlite.v2.db"

if (-not (Test-Path $lifeCoachDir)) {
  New-Item -ItemType Directory -Path $lifeCoachDir -Force | Out-Null
}

function Write-Log($msg) {
  Add-Content -Path $log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" -Encoding UTF8
}

try {
  Write-Log "START prune"
  if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "python is not on PATH; install Python or add it to PATH before pruning"
  }
  if (-not (Test-Path $db)) {
    throw "database not found: $db"
  }
  Get-Process -Name "aw-qt","aw-server","aw-server-rust","aw-watcher-afk","aw-watcher-window","aw-watcher-input","aw-notify" -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $py = @"
import os, sqlite3
from datetime import datetime, timedelta, timezone
db = r'''$db'''
con = sqlite3.connect(db, timeout=120)
con.execute('PRAGMA busy_timeout=120000')
cur = con.cursor()
before = cur.execute('SELECT COUNT(*) FROM eventmodel').fetchone()[0]
cutoff = (datetime.now(timezone.utc) - timedelta(days=60)).strftime('%Y-%m-%d %H:%M:%S')
cur.execute('DELETE FROM eventmodel WHERE timestamp < ?', (cutoff,))
deleted = con.total_changes
con.commit()
after = cur.execute('SELECT COUNT(*) FROM eventmodel').fetchone()[0]
print(f'before={before} deleted={deleted} after={after} cutoff={cutoff}')
print('vacuum...')
cur.execute('VACUUM')
con.close()
print('size_mb', round(os.path.getsize(db)/1024/1024, 2))
"@
  $pyPath = Join-Path $env:TEMP "aw_prune_run.py"
  Set-Content -Path $pyPath -Value $py -Encoding UTF8
  $out = & python $pyPath 2>&1 | Out-String
  Write-Log $out.Trim()
  if (Test-Path $awQt) {
    Start-Process -FilePath $awQt -WorkingDirectory (Split-Path $awQt)
    Write-Log "restarted aw-qt"
  }
  Write-Log "DONE"
} catch {
  Write-Log "ERR $_"
  if (Test-Path $awQt) { Start-Process -FilePath $awQt -WorkingDirectory (Split-Path $awQt) }
  throw
}
