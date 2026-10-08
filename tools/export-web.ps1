param([Parameter(Mandatory=$true)][string]$GodotExe)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$exportDirectory = Join-Path $projectRoot 'build\web'
$webDirectory = Join-Path $projectRoot 'docs'
New-Item -ItemType Directory -Path $exportDirectory -Force | Out-Null
& $GodotExe --headless --editor --path $projectRoot --import --quit
if ($LASTEXITCODE -ne 0) { throw '项目导入失败' }
& $GodotExe --headless --path $projectRoot --export-release Web (Join-Path $exportDirectory 'index.html')
if ($LASTEXITCODE -ne 0) { throw 'Web 导出失败；请确认已安装 Godot 4.7.2 导出模板' }
Get-ChildItem -LiteralPath $exportDirectory -File | Where-Object { $_.Name -ne 'index.html' } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $webDirectory $_.Name) -Force
}
$html = [IO.File]::ReadAllText((Join-Path $exportDirectory 'index.html')).Replace('lang="en"', 'lang="zh-CN"')
[IO.File]::WriteAllText((Join-Path $webDirectory 'game.html'), $html, [Text.UTF8Encoding]::new($false))
Write-Output '网页版已更新：docs/game.html；中文试玩入口保留。'
