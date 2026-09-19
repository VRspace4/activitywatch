# Windows durability (Life Coach)

Operational scripts applied live on 2026-09-19 after Python `aw-server` v0.13.2 died overnight. They keep a per-user ActivityWatch install answering on `http://127.0.0.1:5600` and cap the peewee SQLite event store.

These scripts do **not** change the default ActivityWatch product. They are extras for this maintained fork.

## What broke

- Installed AW v0.13.2 (Python `aw-server`) on Windows.
- `peewee-sqlite.v2.db` grew to about **177MB / 746k events** (~10 months).
- Logs showed `MemoryError` and peewee `OperationalError` disk I/O.
- The process died overnight. The Startup `.lnk` alone did not restart the stack.
- Local API `:5600` refused connections; the study timer showed 0.

Live recovery: stopped AW, deleted events older than 60 days, `VACUUM` (DB ~41MB), then installed a 5-minute watchdog and a monthly prune task.

## What these scripts do

| Script | Behavior |
| --- | --- |
| [`aw-watchdog.ps1`](./aw-watchdog.ps1) | If `http://127.0.0.1:5600/api/0/info` is not HTTP 200, kill `aw-*` processes and restart `%LOCALAPPDATA%\Programs\ActivityWatch\aw-qt.exe`. Rotates its log at 2MB. |
| [`aw-prune.ps1`](./aw-prune.ps1) | Stop AW, `DELETE` `eventmodel` rows older than **60 days**, `VACUUM`, restart `aw-qt`. Requires `python` on `PATH`. Always attempts restart on error. |
| [`install.ps1`](./install.ps1) | Copies the two scripts to `%LOCALAPPDATA%\life-coach\`, registers the Scheduled Tasks, and points Startup at `aw-qt.exe`. |

All paths use `%LOCALAPPDATA%` / environment variables. Do not hardcode a Windows username.

## Install (current user)

From a PowerShell prompt as the logged-in user, in this directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

That will:

1. Copy `aw-watchdog.ps1` and `aw-prune.ps1` to `%LOCALAPPDATA%\life-coach\`
2. Register current-user Scheduled Tasks:
   - `LifeCoach-ActivityWatch-Watchdog` — every 5 minutes
   - `LifeCoach-ActivityWatch-Prune` — monthly, day 1, 03:15
3. Create or retarget `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ActivityWatch.lnk` to `%LOCALAPPDATA%\Programs\ActivityWatch\aw-qt.exe`

### Manual Scheduled Task registration

If you prefer not to run `install.ps1`:

```powershell
$lc = Join-Path $env:LOCALAPPDATA "life-coach"
New-Item -ItemType Directory -Path $lc -Force | Out-Null
Copy-Item .\aw-watchdog.ps1,.\aw-prune.ps1 $lc -Force

schtasks /Create /F /RL LIMITED /TN "LifeCoach-ActivityWatch-Watchdog" /SC MINUTE /MO 5 /TR "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$lc\aw-watchdog.ps1`""

schtasks /Create /F /RL LIMITED /TN "LifeCoach-ActivityWatch-Prune" /SC MONTHLY /D 1 /ST 03:15 /TR "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$lc\aw-prune.ps1`""
```

### Startup shortcut

A login shortcut only starts ActivityWatch at logon. It does **not** recover from a crash later in the day. Point it at `aw-qt.exe` (not a stale path):

```powershell
$awQt = Join-Path $env:LOCALAPPDATA "Programs\ActivityWatch\aw-qt.exe"
$lnkPath = Join-Path ([Environment]::GetFolderPath("Startup")) "ActivityWatch.lnk"
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut($lnkPath)
$lnk.TargetPath = $awQt
$lnk.WorkingDirectory = Split-Path $awQt
$lnk.Save()
```

## Assumptions

- Per-user installer: `aw-qt.exe` lives under `%LOCALAPPDATA%\Programs\ActivityWatch\`
- Python server DB: `%LOCALAPPDATA%\activitywatch\activitywatch\aw-server\peewee-sqlite.v2.db`
- API probe: `http://127.0.0.1:5600/api/0/info`
- Prune needs `python` on `PATH` (stdlib `sqlite3` only)
- Tasks run as the **current user**, so they can stop/start that user's `aw-*` processes

If you use an all-users install (`Program Files`) or `aw-server-rust` as the datastore, adjust the `aw-qt` / DB paths before relying on prune.

## Logs

- `%LOCALAPPDATA%\life-coach\aw-watchdog.log` (rotated to `aw-watchdog.log.old` at 2MB)
- `%LOCALAPPDATA%\life-coach\aw-prune.log`

## Large DB / Python server

Prefer `aw-server-rust` when the event store is already large. The Python server is the current default on many Windows installs and is the process that hit `MemoryError` in the Life Coach incident. See the [contrib README](../README.md) for that recommendation. This folder does not change the product default; it keeps the Python-server install recoverable until you migrate.
