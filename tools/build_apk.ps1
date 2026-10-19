# 打一个正式版 APK
#
# 中文路径会让 Dart 的 AOT 快照器挂掉（"Unable to read file ... app.dill"），
# 所以先把 app/ 镜像到纯英文路径再编译，产物拷回 dist/。
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'app'
$work = 'C:\nailong_build\app'

Write-Host "== 镜像到 $work ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force $work | Out-Null
robocopy $src $work /E /XD build .dart_tool .gradle .idea /XF *.apk /NFL /NDL /NJH /NJS /NP | Out-Null

Write-Host "== flutter build apk --release ==" -ForegroundColor Cyan
Push-Location $work
flutter build apk --release
$code = $LASTEXITCODE
Pop-Location
if ($code -ne 0) { throw "构建失败（exit $code）" }

$apk = Join-Path $work 'build\app\outputs\flutter-apk\app-release.apk'
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$target = Join-Path $dist 'NailongPet.apk'
Copy-Item $apk $target -Force

$size = [math]::Round((Get-Item $target).Length / 1MB, 1)
Write-Host "== 完成：$target ($size MB) ==" -ForegroundColor Green
