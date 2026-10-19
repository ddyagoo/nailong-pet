# 打 Windows 安装包（NSIS Setup.exe）
# 产物：dist/windows/NailongPet-Setup-<version>.exe
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = Split-Path -Parent $here
$web = Join-Path $root 'app\build\web'
$dist = Join-Path $root 'dist\windows'

if (-not (Test-Path (Join-Path $web 'index.html'))) {
  throw "找不到 $web，先跑：cd app; flutter build web --release"
}
if (-not (Test-Path (Join-Path $here 'node_modules\electron-builder'))) {
  throw '还没装 electron-builder，先跑：cd desktop; npm install'
}

Write-Host '== 同步 web 构建到 desktop/web ==' -ForegroundColor Cyan
$dstWeb = Join-Path $here 'web'
if (Test-Path $dstWeb) { Remove-Item -Recurse -Force $dstWeb }
Copy-Item $web $dstWeb -Recurse

Write-Host '== electron-builder (nsis) ==' -ForegroundColor Cyan
Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
Push-Location $here
try {
  npx electron-builder --win nsis
  if ($LASTEXITCODE -ne 0) { throw "electron-builder 失败（exit $LASTEXITCODE）" }
} finally {
  Pop-Location
}

$setup = Get-ChildItem $dist -Filter 'NailongPet-Setup-*.exe' |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $setup) { throw '没找到生成的安装包' }
$size = [math]::Round($setup.Length / 1MB, 1)
Write-Host "== 完成：$($setup.FullName) ($size MB) ==" -ForegroundColor Green
