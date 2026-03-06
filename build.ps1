# ============================================================
#  build.ps1 — compiles src/ into dist/monitor.ps1
#  Usage: powershell -ExecutionPolicy Bypass -File build.ps1
# ============================================================

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = "$root\src"
$dist = "$root\dist"

if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist | Out-Null }

Write-Host ''
Write-Host '  Health Monitor — Build' -ForegroundColor DarkGray
Write-Host '  ----------------------' -ForegroundColor DarkGray

$config   = Get-Content "$src\config.ps1"   -Raw -Encoding UTF8
$template = Get-Content "$src\template.html" -Raw -Encoding UTF8
$monitor  = Get-Content "$src\monitor.ps1"   -Raw -Encoding UTF8

# Inline config and template into monitor
$compiled = $monitor `
    -replace '#\s*\{\{CONFIG\}\}',   $config `
    -replace '#\s*\{\{TEMPLATE\}\}', "`$script:templateHtml = @'`n$template`n'@"

$out = "$dist\monitor.ps1"
$compiled | Set-Content $out -Encoding UTF8

$kb = [Math]::Round((Get-Item $out).Length / 1KB, 1)
Write-Host "  dist\monitor.ps1  ($kb KB)" -ForegroundColor Green
Write-Host ''
Write-Host '  Run with:' -ForegroundColor DarkGray
Write-Host '  powershell -ExecutionPolicy Bypass -File dist\monitor.ps1' -ForegroundColor DarkGray
Write-Host ''
