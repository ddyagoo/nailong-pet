# 从源码跑 Windows 版：先装依赖，再启动 Electron
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# 某些终端（比如 IDE 里）会带这个变量，带上它 Electron 会退化成纯 Node
Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue

if (-not (Test-Path 'node_modules/electron/dist/electron.exe')) {
  Write-Host '首次运行，安装 Electron（约 100MB）…' -ForegroundColor Cyan
  npm install --no-audit --no-fund
  if (-not (Test-Path 'node_modules/electron/dist/electron.exe')) {
    $v = (Get-Content 'node_modules/electron/package.json' -Raw | ConvertFrom-Json).version
    Write-Host "手动下载 Electron $v …" -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://npmmirror.com/mirrors/electron/$v/electron-v$v-win32-x64.zip" -OutFile 'electron.zip'
    Expand-Archive -Path 'electron.zip' -DestinationPath 'node_modules/electron/dist' -Force
    Set-Content -Path 'node_modules/electron/path.txt' -Value 'electron.exe' -NoNewline
    Remove-Item 'electron.zip'
  }
}

& "$PSScriptRoot/node_modules/.bin/electron.cmd" .
