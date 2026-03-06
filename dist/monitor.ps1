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


$script:templateHtml = @'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>{{TITLE}}</title>
  <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg:        #f0efe9;
      --surface:   #faf9f7;
      --border:    #e2e0d8;
      --text:      #18170f;
      --faint:     #b8b5ac;
      --ok:        #15622e;
      --ok-bg:     #d9f5e5;
      --ok-glow:   #a7e8c4;
      --warn:      #7a4a00;
      --warn-bg:   #fdf0cc;
      --warn-glow: #f5d97a;
      --fail:      #8f1a1a;
      --fail-bg:   #fde8e8;
      --fail-glow: #f5b4b4;
      --mono: 'IBM Plex Mono', monospace;
      --sans: 'IBM Plex Sans', sans-serif;
      --cols: {{GRID_COLS}};
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: var(--bg); font-family: var(--sans); color: var(--text); padding: 60px 68px; min-height: 100vh; }

    .header { max-width: 900px; margin-bottom: 44px; display: flex; align-items: flex-end; justify-content: space-between; padding-bottom: 20px; border-bottom: 1.5px solid var(--border); }
    .title   { font-size: 36px; font-weight: 600; letter-spacing: -.03em; }
    .subtitle { font-family: var(--mono); font-size: 12px; color: var(--faint); letter-spacing: .08em; margin-top: 10px; text-transform: uppercase; }
    .header-right { display: flex; flex-direction: column; align-items: flex-end; gap: 8px; }
    .timestamp { font-family: var(--mono); font-size: 13px; color: var(--faint); }
    .hint      { font-family: var(--mono); font-size: 11px; color: var(--faint); opacity: .5; }

    .grid { display: grid; grid-template-columns: repeat(var(--cols), 1fr); gap: 12px; max-width: 900px; }

    .host-card { position: relative; background: var(--surface); border: 1.5px solid var(--border); border-radius: 14px; padding: 22px 20px 18px; cursor: default; transition: all .15s ease; overflow: hidden; }
    .host-card::after { content: ''; position: absolute; inset: 0; opacity: 0; transition: opacity .15s; pointer-events: none; }
    .host-card.ok::after   { background: var(--ok-bg); }
    .host-card.warn::after { background: var(--warn-bg); }
    .host-card.fail::after { background: var(--fail-bg); }
    .host-card:hover { transform: translateY(-2px); }
    .host-card:hover::after { opacity: 1; }
    .host-card.ok:hover   { border-color: var(--ok-glow);   box-shadow: 0 8px 28px rgba(21,98,46,.1); }
    .host-card.warn:hover { border-color: var(--warn-glow); box-shadow: 0 8px 28px rgba(122,74,0,.1); }
    .host-card.fail:hover { border-color: var(--fail-glow); box-shadow: 0 8px 28px rgba(143,26,26,.1); }

    .bar { position: absolute; top: 0; left: 0; right: 0; height: 3px; border-radius: 14px 14px 0 0; }
    .ok   .bar { background: #2dcc6e; }
    .warn .bar { background: #f5a800; }
    .fail .bar { background: #e84040; }

    .dot { position: absolute; top: 18px; right: 18px; width: 9px; height: 9px; border-radius: 50%; z-index: 2; }
    .ok   .dot { background: #2dcc6e; box-shadow: 0 0 0 3px rgba(45,204,110,.18); }
    .warn .dot { background: #f5a800; box-shadow: 0 0 0 3px rgba(245,168,0,.18); }
    .fail .dot { background: #e84040; box-shadow: 0 0 0 3px rgba(232,64,64,.18); }

    .host-name   { display: block; font-family: var(--mono); font-size: 19px; font-weight: 500; color: var(--text); position: relative; z-index: 2; transition: color .15s; }
    .host-detail { display: block; font-family: var(--mono); font-size: 11px; color: var(--faint); margin-top: 10px; position: relative; z-index: 2; opacity: 0; transform: translateY(5px); transition: opacity .15s, transform .15s; }
    .host-card:hover .host-name   { }
    .host-card.ok:hover   .host-name { color: var(--ok); }
    .host-card.warn:hover .host-name { color: var(--warn); }
    .host-card.fail:hover .host-name { color: var(--fail); }
    .host-card:hover .host-detail { opacity: 1; transform: translateY(0); }

    .footer  { max-width: 900px; margin-top: 28px; display: flex; align-items: center; justify-content: space-between; }
    .summary { display: flex; gap: 8px; }
    .chip    { display: inline-flex; align-items: center; gap: 9px; padding: 8px 18px; border-radius: 28px; font-size: 15px; font-weight: 500; border: 1.5px solid transparent; }
    .chip.ok   { color: var(--ok);   background: var(--ok-bg);   border-color: var(--ok-glow); }
    .chip.warn { color: var(--warn); background: var(--warn-bg); border-color: var(--warn-glow); }
    .chip.fail { color: var(--fail); background: var(--fail-bg); border-color: var(--fail-glow); }
    .chip-val { font-size: 20px; font-weight: 600; line-height: 1; font-family: var(--mono); }
    .elapsed  { font-family: var(--mono); font-size: 12px; color: var(--faint); }
  </style>
</head>
<body>

<div class="header">
  <div>
    <div class="title">{{TITLE}}</div>
    <div class="subtitle">{{SUBTITLE}}</div>
  </div>
  <div class="header-right">
    <span class="timestamp">{{TIMESTAMP}}</span>
    <span class="hint">R — refresh &nbsp;&nbsp; Q — quit</span>
  </div>
</div>

<div class="grid">{{CARDS}}</div>

<div class="footer">
  <div class="summary">
    <div class="chip ok">  <span class="chip-val">{{OK_COUNT}}</span>OK</div>
    <div class="chip warn"><span class="chip-val">{{WARN_COUNT}}</span>Warn</div>
    <div class="chip fail"><span class="chip-val">{{FAIL_COUNT}}</span>Fail</div>
  </div>
  <span class="elapsed">{{ELAPSED}}s</span>
</div>

<script>
var token = {{TOKEN}};
function poll() {
  fetch('/token')
    .then(function(r) { return r.json(); })
    .then(function(d) {
      if (d.token !== token) { location.reload(); }
      else { setTimeout(poll, 2000); }
    })
    .catch(function() { setTimeout(poll, 3000); });
}
setTimeout(poll, 2000);

window.addEventListener('beforeunload', function() {
  navigator.sendBeacon('/shutdown');
});
</script>

</body>
</html>

'@

$flagPath        = "$env:USERPROFILE\hmon_flag"
$script:html     = ''
$script:token    = 0
$script:checking = $false

function Build-Html($results, $elapsed, $ts, $token) {
    $ok   = ($results | Where-Object Cls -eq 'ok').Count
    $warn = ($results | Where-Object Cls -eq 'warn').Count
    $fail = ($results | Where-Object Cls -eq 'fail').Count
    $cards = ($results | ForEach-Object {
        $pt = if ($_.PingOk) {'ping ok'} else {'no ping'}
        $ht = if ($_.Http -eq 0) {'no response'} else {"http $($_.Http)"}
        "<div class=`"host-card $($_.Cls)`">" +
        "<div class=`"bar`"></div><div class=`"dot`"></div>" +
        "<span class=`"host-name`">$($_.Host)</span>" +
        "<span class=`"host-detail`">$pt / $ht</span></div>"
    }) -join ''
    $script:templateHtml `
        -replace '{{TITLE}}',      $CONFIG_TITLE `
        -replace '{{SUBTITLE}}',   "Health Check / $($CONFIG_HOSTS.Count) hosts" `
        -replace '{{TIMESTAMP}}',  $ts `
        -replace '{{GRID_COLS}}',  "$CONFIG_GRID_COLS" `
        -replace '{{CARDS}}',      $cards `
        -replace '{{OK_COUNT}}',   "$ok" `
        -replace '{{WARN_COUNT}}', "$warn" `
        -replace '{{FAIL_COUNT}}', "$fail" `
        -replace '{{ELAPSED}}',    $elapsed `
        -replace '{{TOKEN}}',      "$token"
}

function Run-Check {
    if ($script:checking) { return }
    $script:checking = $true
    $sw   = [System.Diagnostics.Stopwatch]::StartNew()
    $pool = [RunspaceFactory]::CreateRunspacePool(1, $CONFIG_HOSTS.Count)
    $pool.Open()
    $job_script = {
        param($h, $path, $tsec, $pms)
        $ping = $false; $http = 0; $status = 'OFFLINE'; $cls = 'fail'
        try { $ping = (New-Object System.Net.NetworkInformation.Ping).Send($h, $pms).Status -eq 'Success' } catch {}
        if ($ping) {
            try {
                $r = [System.Net.WebRequest]::Create("http://$h$path")
                $r.Timeout = $tsec * 1000; $r.Method = 'GET'
                $rs = $r.GetResponse(); $http = [int]$rs.StatusCode; $rs.Close()
            } catch [System.Net.WebException] {
                $http = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            } catch { $http = 0 }
        }
        if (-not $ping)        { $status = 'OFFLINE'; $cls = 'fail' }
        elseif ($http -eq 200) { $status = 'OK';      $cls = 'ok'   }
        else                   { $status = 'WARN';    $cls = 'warn'  }
        [PSCustomObject]@{ Host=$h; PingOk=$ping; Http=$http; Status=$status; Cls=$cls }
    }
    $jobs = foreach ($h in $CONFIG_HOSTS) {
        $ps = [PowerShell]::Create(); $ps.RunspacePool = $pool
        [void]$ps.AddScript($job_script)
        [void]$ps.AddArgument($h)
        [void]$ps.AddArgument($CONFIG_HEALTH_PATH)
        [void]$ps.AddArgument($CONFIG_TIMEOUT_SEC)
        [void]$ps.AddArgument($CONFIG_PING_TIMEOUT_MS)
        [PSCustomObject]@{ PS=$ps; H=$ps.BeginInvoke(); Host=$h }
    }
    $map = @{}
    foreach ($j in $jobs) { $map[$j.Host] = $j.PS.EndInvoke($j.H); $j.PS.Dispose() }
    $pool.Close(); $pool.Dispose()
    $results = $CONFIG_HOSTS | ForEach-Object { $map[$_] }
    $sw.Stop()
    $elapsed = $sw.Elapsed.TotalSeconds.ToString('0.00')
    $ts      = Get-Date -f 'yyyy-MM-dd  HH:mm:ss'
    $token   = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    foreach ($r in $results) {
        $col  = @{ ok='Green'; warn='Yellow'; fail='Red' }[$r.Cls]
        $icon = @{ ok='OK  '; warn='WARN'; fail='FAIL' }[$r.Cls]
        Write-Host "  [$icon] $($r.Host)  http=$($r.Http)" -ForegroundColor $col
    }
    $ok = ($results | Where-Object Cls -eq 'ok').Count
    $w  = ($results | Where-Object Cls -eq 'warn').Count
    $f  = ($results | Where-Object Cls -eq 'fail').Count
    Write-Host "  OK:$ok  WARN:$w  FAIL:$f  (${elapsed}s)" -ForegroundColor DarkGray
    Write-Host ''
    $script:html     = Build-Html $results $elapsed $ts $token
    $script:token    = $token
    $script:checking = $false
}

function Commit {
    [System.IO.File]::WriteAllText("$flagPath.html", $script:html,    [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText("$flagPath.tok",  "$script:token", [System.Text.Encoding]::UTF8)
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$CONFIG_PORT/")
try { $listener.Start() }
catch {
    Write-Host "  [ERROR] Port $CONFIG_PORT is busy. Change CONFIG_PORT in config.ps1 and rebuild." -ForegroundColor Red
    Read-Host; exit 1
}

$srv = [PowerShell]::Create()
[void]$srv.AddScript({
    param($L, $fp)
    while ($L.IsListening) {
        try {
            $ctx = $L.GetContext()
            $p   = $ctx.Request.Url.AbsolutePath
            $res = $ctx.Response
            $res.Headers.Add('Cache-Control', 'no-store')
            switch ($p) {
                '/token'    { $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"token":' + [System.IO.File]::ReadAllText("$fp.tok") + '}'); $res.ContentType = 'application/json' }
                '/refresh'  { [System.IO.File]::WriteAllText($fp, 'refresh'); $bytes = [System.Text.Encoding]::UTF8.GetBytes('ok'); $res.ContentType = 'text/plain' }
                '/shutdown' { [System.IO.File]::WriteAllText($fp, 'shutdown'); $bytes = [System.Text.Encoding]::UTF8.GetBytes('bye'); $res.ContentType = 'text/plain' }
                default     { $bytes = [System.Text.Encoding]::UTF8.GetBytes([System.IO.File]::ReadAllText("$fp.html")); $res.ContentType = 'text/html; charset=utf-8' }
            }
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            $res.OutputStream.Close()
        } catch {}
    }
})
[void]$srv.AddArgument($listener)
[void]$srv.AddArgument($flagPath)
$srv.BeginInvoke() | Out-Null

function Open-Chrome($url) {
    $exe = $CONFIG_CHROME_PATHS | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($exe) { Start-Process $exe $url } else { Start-Process $url }
}

Write-Host ''
Write-Host '  Health Monitor' -ForegroundColor DarkGray
Write-Host '  --------------' -ForegroundColor DarkGray
Write-Host "  $($CONFIG_HOSTS.Count) hosts / port $CONFIG_PORT" -ForegroundColor DarkGray
Write-Host ''

Run-Check
Commit
[System.IO.File]::WriteAllText($flagPath, '0')
Open-Chrome "http://localhost:$CONFIG_PORT/"
Write-Host "  http://localhost:$CONFIG_PORT/" -ForegroundColor DarkGray
Write-Host '  [R] refresh   [Q] quit' -ForegroundColor DarkGray
Write-Host ''

while ($true) {
    try { $flag = ([System.IO.File]::ReadAllText($flagPath)).Trim() } catch { $flag = '0' }
    if ($flag -eq 'shutdown') { Write-Host '  [tab closed] shutting down...' -ForegroundColor DarkGray; break }
    if ($flag -eq 'refresh') {
        [System.IO.File]::WriteAllText($flagPath, '0')
        Write-Host '  [F5] refreshing...' -ForegroundColor DarkGray
        Run-Check; Commit
        Write-Host '  [R] refresh   [Q] quit' -ForegroundColor DarkGray
    }
    if ([Console]::KeyAvailable) {
        $k = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        if ($k.Character -match '[rR]') {
            Write-Host '  [R] refreshing...' -ForegroundColor DarkGray
            Run-Check; Commit
            Write-Host '  [R] refresh   [Q] quit' -ForegroundColor DarkGray
        } elseif ($k.Character -match '[qQ]') { break }
    }
    Start-Sleep -Milliseconds 200
}

$listener.Stop()
$srv.Dispose()
Remove-Item "$flagPath*" -ErrorAction SilentlyContinue
Write-Host '  bye.' -ForegroundColor DarkGray
