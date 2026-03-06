# ============================================================
#  Health Monitor — monitor.ps1  (source, not for direct use)
#  Run build.ps1 to produce the final compiled script.
# ============================================================

# --- config and template are inlined here by build.ps1 ---
# {{CONFIG}}
# {{TEMPLATE}}

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
    [System.IO.File]::WriteAllText("$flagPath.html", $script:html,   [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText("$flagPath.tok",  "$script:token", [System.Text.Encoding]::UTF8)
}

# HTTP server (background runspace)
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
                '/token'    {
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"token":' + [System.IO.File]::ReadAllText("$fp.tok") + '}')
                    $res.ContentType = 'application/json'
                }
                '/refresh'  {
                    [System.IO.File]::WriteAllText($fp, 'refresh')
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes('ok')
                    $res.ContentType = 'text/plain'
                }
                '/shutdown' {
                    [System.IO.File]::WriteAllText($fp, 'shutdown')
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes('bye')
                    $res.ContentType = 'text/plain'
                }
                default     {
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes([System.IO.File]::ReadAllText("$fp.html"))
                    $res.ContentType = 'text/html; charset=utf-8'
                }
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

# First run
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

# Main loop
while ($true) {
    try { $flag = ([System.IO.File]::ReadAllText($flagPath)).Trim() } catch { $flag = '0' }

    if ($flag -eq 'shutdown') {
        Write-Host '  [tab closed] shutting down...' -ForegroundColor DarkGray
        break
    }
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
        }
        elseif ($k.Character -match '[qQ]') { break }
    }

    Start-Sleep -Milliseconds 200
}

# Cleanup
$listener.Stop()
$srv.Dispose()
Remove-Item "$flagPath*" -ErrorAction SilentlyContinue
Write-Host '  bye.' -ForegroundColor DarkGray
