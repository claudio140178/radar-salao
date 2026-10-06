# Publica a pagina de agendamentos da Ana (nao aparece no Google)
param([string]$Repo = "C:\Users\claud\morgana-silveira", [string]$Origem = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
Set-Location $Repo
git pull --ff-only
if ($LASTEXITCODE) { throw 'git pull falhou.' }
Copy-Item (Join-Path $Origem 'agenda-ana.html') (Join-Path $Repo 'agenda-ana.html') -Force
git add -- agenda-ana.html
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host 'Nada novo.'; return }
git commit -m 'Pagina de agendamentos da Ana (noindex)'
git push
if ($LASTEXITCODE) { throw 'git push falhou.' }
Write-Host "`nPublicado. Em 2 minutos abra: https://morganasilveirastudiodebeleza.online/agenda-ana" -ForegroundColor Green
