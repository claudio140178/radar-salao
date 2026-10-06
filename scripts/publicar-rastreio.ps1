# Coloca o rastreio de cliques no WhatsApp em todas as paginas e publica
param([string]$Repo = "C:\Users\claud\morgana-silveira", [string]$Origem = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
Set-Location $Repo
git pull --ff-only
if ($LASTEXITCODE) { throw 'git pull falhou.' }
Copy-Item (Join-Path $Origem 'rastreio.js') (Join-Path $Repo 'rastreio.js') -Force
$tag = '<script src="/rastreio.js" defer></script>'
$paginas = @('index.html','mechas-coqueiros-florianopolis.html','unhas-fibra-gel-coqueiros-florianopolis.html','progressiva-coqueiros-florianopolis.html')
foreach ($p in $paginas) {
  $f = Join-Path $Repo $p
  if (-not (Test-Path $f)) { Write-Warning "Nao achei $p"; continue }
  $h = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
  if ($h -match 'rastreio\.js') { Write-Host "  ja tinha: $p"; continue }
  $i = $h.LastIndexOf('</body>')
  if ($i -lt 0) { Write-Warning "Sem </body> em $p"; continue }
  [IO.File]::WriteAllText($f, $h.Insert($i, "$tag`n"), $Utf8)
  Write-Host "  rastreio adicionado: $p" -ForegroundColor Green
}
git add -- rastreio.js $paginas
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host 'Nada novo.'; return }
git commit -m 'Rastreio de cliques no WhatsApp (radar)'
git push
if ($LASTEXITCODE) { throw 'git push falhou.' }
Write-Host "`nPublicado. Em 2 minutos os cliques no WhatsApp passam a ser contados." -ForegroundColor Green
