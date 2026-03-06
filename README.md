# ps-health-monitor

A minimal Windows health dashboard for HTTP services — single `.ps1` file, no dependencies, opens in Chrome.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue) ![Platform](https://img.shields.io/badge/platform-Windows-blue) ![License](https://img.shields.io/badge/license-MIT-green)

---

## What it does

Checks a list of hosts in parallel and opens a live dashboard in Chrome. Press **R** to re-check, **F5** in the browser does the same. Close the tab — the script exits.

![dashboard preview](docs/preview.png)

---

## Quick start

**1. Allow PS scripts to run** *(one time, run as admin)*

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

**2. Edit config** — open `src/config.ps1`, set your hosts and health endpoint

**3. Build**

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
```

**4. Run**

```powershell
powershell -ExecutionPolicy Bypass -File dist\monitor.ps1
```

Or right-click → **Run with PowerShell** after step 1.

---

## Configuration

All settings are in `src/config.ps1`:

| Variable | Default | Description |
|---|---|---|
| `$CONFIG_PORT` | `5757` | Local HTTP server port |
| `$CONFIG_HEALTH_PATH` | `:80/health` | Path appended to each hostname |
| `$CONFIG_TIMEOUT_SEC` | `8` | HTTP request timeout per host |
| `$CONFIG_PING_TIMEOUT_MS` | `2000` | ICMP ping timeout in ms |
| `$CONFIG_HOSTS` | *(array)* | Hostnames or IPs to monitor |
| `$CONFIG_CHROME_PATHS` | *(standard paths)* | Chrome executable locations |
| `$CONFIG_TITLE` | `Health Monitor` | Dashboard title |
| `$CONFIG_GRID_COLS` | `4` | Grid columns: `2`, `3`, `4`, or `6` |

### Examples

```powershell
# Different endpoint
$CONFIG_HEALTH_PATH = ':8080/api/v1/status'

# IPs instead of hostnames
$CONFIG_HOSTS = @(
    '192.168.1.10'
    '192.168.1.11'
    '192.168.1.12'
)

# Compact 3-column layout
$CONFIG_GRID_COLS = 3
```

After editing config, run `build.ps1` again to recompile.

---

## How it works

- **Parallel checks** — all hosts run simultaneously via a PowerShell Runspace pool. Total time = slowest host, not the sum.
- **Local HTTP server** — `System.Net.HttpListener` on `localhost:PORT` serves the dashboard to Chrome.
- **Token polling** — the page checks `/token` every 2 seconds. Nothing happens until a check completes and the token changes — no flicker, no scroll reset.
- **R key** — triggers a new check from the console, browser reloads automatically when done.
- **F5 in browser** — sends `GET /refresh` to the server, which signals the PS loop to run a check.
- **Tab close** — `sendBeacon('/shutdown')` tells the server to stop. PS loop exits and cleans up temp files.

---

## Project structure

```
ps-health-monitor/
├── src/
│   ├── config.ps1      — all settings
│   ├── template.html   — dashboard HTML/CSS with {{PLACEHOLDERS}}
│   └── monitor.ps1     — source script (config + template are placeholders)
├── dist/
│   └── monitor.ps1     — compiled output (run this)
├── docs/
│   └── ARCHITECTURE.md — internals
├── build.ps1           — compiles src/ → dist/monitor.ps1
└── README.md
```

---

## Template placeholders

Edit `src/template.html` to change the dashboard look. Available placeholders:

| Placeholder | Value |
|---|---|
| `{{TITLE}}` | `$CONFIG_TITLE` |
| `{{SUBTITLE}}` | `"Health Check / N hosts"` |
| `{{TIMESTAMP}}` | datetime of last check |
| `{{GRID_COLS}}` | `$CONFIG_GRID_COLS` |
| `{{CARDS}}` | generated host cards HTML |
| `{{OK_COUNT}}` | hosts with HTTP 200 |
| `{{WARN_COUNT}}` | reachable but non-200 |
| `{{FAIL_COUNT}}` | unreachable hosts |
| `{{ELAPSED}}` | check duration in seconds |
| `{{TOKEN}}` | unix ms timestamp for polling |

---

## Requirements

- Windows 10 / 11
- PowerShell 5.1+ *(built-in)*
- Google Chrome
- Network access to target hosts

---

## License

MIT
