# 打包 Windows 绿色版：Electron 运行时 + 应用 + Flutter web 构建
# 产物：dist/windows/NailongPet-win-x64.zip
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = Split-Path -Parent $here
$web = Join-Path $root 'app\build\web'
$dist = Join-Path $root 'dist\windows'
$appDir = Join-Path $dist 'NailongPet'
$electron = Join-Path $here 'node_modules\electron\dist'

if (-not (Test-Path (Join-Path $web 'index.html'))) {
  throw "找不到 $web，先跑：cd app; flutter build web --release"
}
if (-not (Test-Path (Join-Path $electron 'electron.exe'))) {
  throw "找不到 Electron 运行时，先跑 desktop\run.ps1 让它下载一次"
}

Write-Host '== 清理旧产物 ==' -ForegroundColor Cyan
if (Test-Path $appDir) { Remove-Item -Recurse -Force $appDir }
New-Item -ItemType Directory -Force $appDir | Out-Null

Write-Host '== 拷贝 Electron 运行时 ==' -ForegroundColor Cyan
Copy-Item -Path (Join-Path $electron '*') -Destination $appDir -Recurse -Force

Write-Host '== 精简语言包 ==' -ForegroundColor Cyan
$locales = Join-Path $appDir 'locales'
if (Test-Path $locales) {
  Get-ChildItem $locales -File | Where-Object { $_.Name -notin @('en-US.pak', 'zh-CN.pak') } | Remove-Item -Force
}

Write-Host '== 放入应用 ==' -ForegroundColor Cyan
$res = Join-Path $appDir 'resources'
$appRes = Join-Path $res 'app'
New-Item -ItemType Directory -Force $appRes | Out-Null
Copy-Item (Join-Path $here 'main.js') $appRes
Copy-Item (Join-Path $here 'preload.js') $appRes
Copy-Item (Join-Path $here 'package.json') $appRes
Copy-Item (Join-Path $here 'assets') (Join-Path $appRes 'assets') -Recurse
Copy-Item $web (Join-Path $appRes 'web') -Recurse
if (Test-Path (Join-Path $res 'default_app.asar')) {
  Remove-Item (Join-Path $res 'default_app.asar') -Force
}

Write-Host '== 改名 ==' -ForegroundColor Cyan
Move-Item (Join-Path $appDir 'electron.exe') (Join-Path $appDir 'NailongPet.exe') -Force

@'
奶龙桌宠（Windows 绿色版）

双击 NailongPet.exe 启动。
- 奶龙会浮在桌面右下角，透明背景、始终置顶
- 左键拖动：挪位置
- 单击：今日播报
- 长按：笑（第三次笑到躺下）
- 右键：菜单（打开设置 / 显示隐藏 / 退出）
- 托盘图标也可以打开设置和退出

设置窗口里改的音量、大小、静置区间，关掉窗口后会同步到奶龙身上。
卸载：直接删掉这个文件夹。
'@ | Set-Content -Path (Join-Path $appDir '使用说明.txt') -Encoding utf8

Write-Host '== 压缩 ==' -ForegroundColor Cyan
$zip = Join-Path $dist 'NailongPet-win-x64.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $appDir -DestinationPath $zip -CompressionLevel Optimal

$size = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host "== 完成：$zip ($size MB) ==" -ForegroundColor Green
