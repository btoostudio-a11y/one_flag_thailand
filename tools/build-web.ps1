param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
$gameRoot = Split-Path $PSScriptRoot -Parent
Push-Location $gameRoot
try {
  # Engine assets are pinned in the game's upstream web.zip (Godot 4.7).
  if (-not (Test-Path "build/web/index.js")) { Expand-Archive -LiteralPath "build/web.zip" -DestinationPath "build" -Force }
  & $Godot --headless --path . --editor --import --quit
  if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
  & $Godot --headless --path . --export-pack "build/web/index.html" "build/web/index.pck"
  if ($LASTEXITCODE -ne 0) { throw "Godot export failed" }
  $htmlPath = Join-Path $gameRoot "build/web/index.html"
  $html = [IO.File]::ReadAllText($htmlPath)
  $size = (Get-Item "build/web/index.pck").Length
  $html = [regex]::Replace($html, '"index.pck":\d+', ('"index.pck":' + $size))
  [IO.File]::WriteAllText($htmlPath, $html)
  $webAssets = @(Get-ChildItem "build/web" -File | Where-Object { $_.Extension -ne ".import" } | Select-Object -ExpandProperty FullName)
  Compress-Archive -LiteralPath $webAssets -DestinationPath "build/standalone-web.zip" -Force
  Write-Host "Ready: build/standalone-web.zip. Run: python tools/serve.py"
} finally { Pop-Location }
