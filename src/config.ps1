# ============================================================
#  Health Monitor — config.ps1
#  Edit this file, then run build.ps1 to compile monitor.ps1
# ============================================================

# --- Server ---
$CONFIG_PORT = 5757                         # Local HTTP server port

# --- Health check ---
$CONFIG_HEALTH_PATH     = ':80/health'      # Appended to each host, e.g. ':81/api/v1/status'
$CONFIG_TIMEOUT_SEC     = 8                 # HTTP timeout per host (seconds)
$CONFIG_PING_TIMEOUT_MS = 2000              # ICMP ping timeout (ms)

# --- Hosts ---
$CONFIG_HOSTS = @(
    'server01'
    'server02'
    'server03'
    'server04'
)

# --- Browser ---
# Paths to try for Chrome. Leave as-is for standard installs.
$CONFIG_CHROME_PATHS = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    "$env:LocalAppData\Google\Chrome\Application\chrome.exe"
)

# --- UI ---
$CONFIG_TITLE     = 'Health Monitor'        # Header title
$CONFIG_GRID_COLS = 4                       # Grid columns: 2, 3, 4, or 6
