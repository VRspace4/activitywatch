# Install Life Coach ActivityWatch durability helpers for the current Windows user.
# Copies watchdog + prune scripts to %LOCALAPPDATA%\life-coach\, registers
# two current-user Scheduled Tasks, and points Startup at aw-qt.exe.
#
# Run from an elevated-or-not PowerShell as the logged-in user:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1

$ErrorActionPreference = "Stop"

$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = Join-Path $env:LOCALAPPDATA "life-coach"
$AwQt = Join-Path $env:LOCALAPPDATA "Programs\ActivityWatch\aw-qt.exe"
$WatchdogName = "LifeCoach-ActivityWatch-Watchdog"
$PruneName = "LifeCoach-ActivityWatch-Prune"
$WatchdogScript = Join-Path $InstallDir "aw-watchdog.ps1"
$PruneScript = Join-Path $InstallDir "aw-prune.ps1"

function Write-Step($msg) {
  Write-Host $msg
}

function Register-CurrentUserTask {
  param(
    [Parameter(Mandatory = $true)][string]$TaskName,
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [Parameter(Mandatory = $true)][string]$Schedule
  )
  $tr = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
  $common = @("/Create", "/TN", $TaskName, "/TR", $tr, "/F", "/RL", "LIMITED")
  if ($Schedule -eq "watchdog") {
    $args = $common + @("/SC", "MINUTE", "/MO", "5")
  } elseif ($Schedule -eq "prune") {
    $args = $common + @("/SC", "MONTHLY", "/D", "1", "/ST", "03:15")
  } else {
    throw "Unknown schedule '$Schedule'"
  }
  & schtasks.exe @args | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "schtasks failed for $TaskName (exit $LASTEXITCODE)"
  }
}

function Set-AwStartupShortcut {
  $startup = [Environment]::GetFolderPath("Startup")
  if (-not $startup) {
    Write-Step "Startup folder not found; skip shortcut"
    return
  }
  $lnkPath = Join-Path $startup "ActivityWatch.lnk"
  if (-not (Test-Path $AwQt)) {
    Write-Step "WARNING: $AwQt not found. Create Startup\ActivityWatch.lnk manually once ActivityWatch is installed."
    return
  }
  $wsh = New-Object -ComObject WScript.Shell
  $lnk = $wsh.CreateShortcut($lnkPath)
  $lnk.TargetPath = $AwQt
  $lnk.WorkingDirectory = Split-Path $AwQt
  $lnk.WindowStyle = 7
  $lnk.Description = "ActivityWatch (aw-qt)"
  $lnk.Save()
  Write-Step "Startup shortcut: $lnkPath -> $AwQt"
}

if (-not (Test-Path (Join-Path $SourceDir "aw-watchdog.ps1"))) {
  throw "aw-watchdog.ps1 not found next to install.ps1"
}
if (-not (Test-Path (Join-Path $SourceDir "aw-prune.ps1"))) {
  throw "aw-prune.ps1 not found next to install.ps1"
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -Path (Join-Path $SourceDir "aw-watchdog.ps1") -Destination $WatchdogScript -Force
Copy-Item -Path (Join-Path $SourceDir "aw-prune.ps1") -Destination $PruneScript -Force
Write-Step "Installed scripts to $InstallDir"

Register-CurrentUserTask -TaskName $WatchdogName -ScriptPath $WatchdogScript -Schedule "watchdog"
Register-CurrentUserTask -TaskName $PruneName -ScriptPath $PruneScript -Schedule "prune"
Write-Step "Registered Scheduled Tasks: $WatchdogName (every 5 min), $PruneName (monthly day 1 at 03:15)"

Set-AwStartupShortcut

Write-Step "Done. Logs: $(Join-Path $InstallDir 'aw-watchdog.log') and $(Join-Path $InstallDir 'aw-prune.log')"
Write-Step "Note: a Startup .lnk only launches AW at login; the 5-minute watchdog restarts a crashed stack."
