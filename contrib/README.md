# Contrib

Optional extras that are not part of the default ActivityWatch product. They are maintained in this fork so operational fixes can live next to upstream and stay mergeable.

## Windows durability

See [`windows-durability/`](./windows-durability/) for Life Coach scripts that keep a local ActivityWatch stack alive on Windows:

- Restart `aw-qt` when `http://127.0.0.1:5600/api/0/info` is down
- Monthly prune of the Python `aw-server` peewee SQLite database (60-day retention + `VACUUM`)

### Large databases / `MemoryError`

The stock Windows installer still defaults to the Python `aw-server`. On a long-lived machine the peewee SQLite file can grow large enough that the Python process hits `MemoryError` or peewee `OperationalError` disk I/O and dies. A Startup `.lnk` does not restart a crashed stack.

If the event store is already large (tens to hundreds of MB, or hundreds of thousands of events), prefer **`aw-server-rust`** when you can switch to it. That is a recommendation based on the 2026-09-19 Life Coach crash (`~177MB` / `~746k` events, Python `aw-server` v0.13.2) — not a change to ActivityWatch's default server. Until a rust-server install is in place, use the prune + watchdog scripts in this folder to cap growth and recover from overnight deaths.
