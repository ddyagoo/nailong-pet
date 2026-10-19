# 打 Windows 安装包（NSIS）
#
# 用 electron-builder 缓存里的 makensis，不用额外装 Inno Setup。
# makensis 不认中文路径，所以脚本和图标先拷到 C:\nailong_build 再编译，
# 产物出到那边后再拷回 dist\windows。
#
# 前置：先跑 tools\build_windows.ps1（会生成 dist\windows\app，镜像里也有 Release）。
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$mirror = 'C:\nailong_build'
$bundleMirror = Join-Path $mirror 'app\build\windows\x64\runner\Release'
$bundleDist = Join-Path $root 'dist\windows\app'
$dist = Join-Path $root 'dist\windows'

$src = if (Test-Path (Join-Path $bundleMirror 'nailong_pet.exe')) { $bundleMirror }
       elseif (Test-Path (Join-Path $bundleDist 'nailong_pet.exe')) { $bundleDist }
       else { throw '找不到 nailong_pet.exe，先跑 tools\build_windows.ps1' }

$makensis = Get-ChildItem "$env:LOCALAPPDATA\electron-builder\Cache" -Recurse -Filter 'makensis.exe' -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $makensis) { throw '找不到 makensis.exe（electron-builder 缓存里应该有）' }

$version = (Select-String -Path (Join-Path $root 'app\pubspec.yaml') -Pattern '^version:\s*([0-9.]+)' |
    Select-Object -First 1).Matches[0].Groups[1].Value
if (-not $version) { $version = '0.2.0' }

# 拷到纯英文路径再编译
New-Item -ItemType Directory -Force $mirror | Out-Null
Copy-Item (Join-Path $root 'tools\installer.nsi') (Join-Path $mirror 'installer.nsi') -Force
Copy-Item (Join-Path $root 'app\windows\runner\resources\app_icon.ico') (Join-Path $mirror 'app_icon.ico') -Force

$tmpOut = Join-Path $mirror "NailongPet-Setup-$version.exe"
if (Test-Path $tmpOut) { Remove-Item $tmpOut -Force }

Write-Host "== makensis ==" -ForegroundColor Cyan
& $makensis.FullName "/DSRCDIR=$src" "/DOUTFILE=$tmpOut" "/DVERSION=$version" "/DICONPATH=$(Join-Path $mirror 'app_icon.ico')" (Join-Path $mirror 'installer.nsi')
if ($LASTEXITCODE -ne 0) { throw "makensis 失败（exit $LASTEXITCODE）" }

New-Item -ItemType Directory -Force $dist | Out-Null
$out = Join-Path $dist "NailongPet-Setup-$version.exe"
Copy-Item $tmpOut $out -Force
$size = [math]::Round((Get-Item $out).Length / 1MB, 1)
Write-Host "== 完成：$out（$size MB）==" -ForegroundColor Green
