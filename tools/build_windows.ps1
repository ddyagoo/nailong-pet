# 构建 Windows 原生版（Flutter 直出，不再用 Electron）
#
# 中文路径会让 Dart 的 AOT 快照器失败（"Unable to read file ... app.dill"），
# 所以先把 app/ 镜像到纯英文路径再编译，产物拷回 dist/windows/app。
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'app'
$work = 'C:\nailong_build\app'

Write-Host "== 镜像到 $work ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force $work | Out-Null
robocopy $src $work /MIR /XD build .dart_tool .gradle .idea ephemeral /XF *.apk /NFL /NDL /NJH /NJS /NP | Out-Null

# 插件符号链接残留会让 flutter 报 "Cannot create link ... errno 183"
$ephemeral = Join-Path $work 'windows\flutter\ephemeral'
if (Test-Path $ephemeral) { Remove-Item $ephemeral -Recurse -Force }

Write-Host "== flutter build windows --release ==" -ForegroundColor Cyan
Push-Location $work
try {
    flutter build windows --release
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($code -ne 0) { throw "构建失败（exit $code）" }

$bundle = Join-Path $work 'build\windows\x64\runner\Release'
$out = Join-Path $root 'dist\windows\app'
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
Copy-Item $bundle $out -Recurse

$exe = Get-ChildItem $out -Filter '*.exe' | Sort-Object Length -Descending | Select-Object -First 1
$size = [math]::Round((Get-ChildItem $out -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
Write-Host "== 完成：$($exe.FullName)（整个包 $size MB）==" -ForegroundColor Green
