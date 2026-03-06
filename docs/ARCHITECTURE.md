# Architecture

## Overview

```
┌─────────────────────────────────────────────────────────┐
│  monitor.ps1                                            │
│                                                         │
│  ┌─────────────────────┐   ┌──────────────────────────┐ │
│  │  Main thread        │   │  Server runspace         │ │
│  │                     │   │                          │ │
│  │  console loop       │   │  HttpListener            │ │
│  │  R → Run-Check()    │   │  GET /       → html file │ │
│  │  Q → exit           │   │  GET /token  → tok file  │ │
│  │                     │   │  GET /refresh → flag     │ │
│  │  Runspace pool      │   │  POST /shutdown → flag   │ │
│  │  parallel checks    │   │                          │ │
│  └──────────┬──────────┘   └──────────────────────────┘ │
│             │   flag files ($env:USERPROFILE\hmon_flag*) │
│             └────────────────────────────────────────── │
└─────────────────────────────────────────────────────────┘
                       │
              http://localhost:5757
                       │
             ┌─────────────────┐
             │  Chrome tab     │
             │                 │
             │  poll /token    │
             │  every 2s       │
             └─────────────────┘
```

---

## Thread communication

Two threads communicate via flag files in `$env:USERPROFILE`:

| File | Written by | Read by | Values |
|---|---|---|---|
| `hmon_flag` | server runspace | main loop | `0`, `refresh`, `shutdown` |
| `hmon_flag.html` | main thread (`Commit`) | server runspace | full dashboard HTML |
| `hmon_flag.tok` | main thread (`Commit`) | server runspace | unix timestamp ms |

PowerShell runspaces don't share scope with the main thread, so files are used as the IPC mechanism.

---

## Parallel health checks

Each check uses a `RunspacePool` so all hosts run simultaneously:

```
host1 ──┐
host2 ──┤── RunspacePool (N threads) ──► collect results ──► build HTML
host3 ──┘
```

Per-host logic:
1. ICMP ping (2s timeout)
2. If ping ok → `HTTP GET http://{host}{CONFIG_HEALTH_PATH}` (8s timeout)
3. Classify: `OK` (200), `WARN` (reachable, non-200), `FAIL` (no ping)

---

## Token polling

Browser JS holds the token from the last page load. Every 2s it fetches `/token`:

```
token matches  →  do nothing, poll again in 2s
token differs  →  location.reload()
```

This means the page never reloads unless a new check has actually completed.

---

## Refresh flows

**R key:**
```
keypress R → Run-Check() → Commit() → new token written
→ poll detects mismatch → location.reload()
```

**F5 / browser refresh:**
```
page loads (shows cached data instantly)
→ JS runs: fetch('/refresh')
→ server writes 'refresh' to flag file
→ main loop reads flag → Run-Check() → Commit() → new token
→ poll detects mismatch → location.reload()
```

**Tab close:**
```
beforeunload → sendBeacon('/shutdown')
→ server writes 'shutdown' to flag file
→ main loop reads flag → break → cleanup → exit
```

---

## Build

`build.ps1` reads the three source files and inlines config and template into the monitor script, producing a single self-contained `dist/monitor.ps1`.
