# Publica as 5 paginas de servicos em Coqueiros, atualiza a home e o sitemap
param([string]$Repo = "C:\Users\claud\morgana-silveira", [string]$Origem = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
function Ler($p) { [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) }
function Gravar($p,$t) { [IO.File]::WriteAllText($p, $t, $Utf8) }
$Dominio = 'https://morganasilveirastudiodebeleza.online'
$Paginas = [ordered]@{
  'mechas-coqueiros-florianopolis'             = 'Mechas e loiro em Coqueiros'
  'loiro-platinado-coqueiros-florianopolis'    = 'Loiro platinado em Coqueiros'
  'unhas-fibra-gel-coqueiros-florianopolis'    = 'Unhas em fibra e gel em Coqueiros'
  'progressiva-coqueiros-florianopolis'        = 'Progressiva em Coqueiros'
  'cilios-sobrancelha-coqueiros-florianopolis' = 'C&iacute;lios e sobrancelha em Coqueiros'
}
Set-Location $Repo
git pull --ff-only
if ($LASTEXITCODE) { throw 'git pull falhou.' }

Write-Host '>> Copiando paginas' -ForegroundColor Magenta
foreach ($s in $Paginas.Keys) { Copy-Item (Join-Path $Origem "$s.html") (Join-Path $Repo "$s.html") -Force; Write-Host "  ok $s" }
if (-not (Test-Path (Join-Path $Repo 'rastreio.js'))) { Copy-Item (Join-Path $Origem 'rastreio.js') $Repo; Write-Host '  ok rastreio.js' }

Write-Host '>> Atualizando a home' -ForegroundColor Magenta
$idx = Join-Path $Repo 'index.html'
$h = Ler $idx
$itens = ($Paginas.Keys | ForEach-Object { "    <li><a href=`"/$_`">$($Paginas[$_])</a></li>" }) -join "`n"
$bloco = "<!-- paginas-seo -->`n<section id=`"saiba-mais`" style=`"max-width:1080px;margin:0 auto;padding:40px 20px`">`n  <h2>Saiba mais</h2>`n  <ul style=`"list-style:none;padding:0;margin:16px 0 0;display:flex;flex-wrap:wrap;gap:12px 28px`">`n$itens`n  </ul>`n</section>`n<!-- /paginas-seo -->"
$a = $h.IndexOf('<!-- paginas-seo -->'); $b = $h.IndexOf('<!-- /paginas-seo -->')
if ($a -ge 0 -and $b -gt $a) { $h = $h.Substring(0,$a) + $bloco + $h.Substring($b + '<!-- /paginas-seo -->'.Length) }
else {
  $pos = $h.IndexOf('</main>'); if ($pos -lt 0) { $pos = $h.IndexOf('<footer') }
  if ($pos -lt 0) { throw 'Nao achei onde colocar os links na home.' }
  $h = $h.Insert($pos, "$bloco`n")
}
if ($h -notmatch 'rastreio\.js') { $h = $h.Insert($h.LastIndexOf('</body>'), "<script src=`"/rastreio.js`" defer></script>`n") }
Gravar $idx $h
Write-Host '  links "Saiba mais" com as 5 paginas'

Write-Host '>> Atualizando sitemap' -ForegroundColor Magenta
$sm = Join-Path $Repo 'sitemap.xml'; $xml = Ler $sm; $hoje = Get-Date -Format 'yyyy-MM-dd'
foreach ($s in $Paginas.Keys) {
  $loc = "$Dominio/$s"
  if ($xml -notmatch [regex]::Escape("<loc>$loc</loc>")) {
    $xml = $xml.Replace('</urlset>', "  <url>`n    <loc>$loc</loc>`n    <lastmod>$hoje</lastmod>`n    <changefreq>monthly</changefreq>`n    <priority>0.8</priority>`n  </url>`n</urlset>")
    Write-Host "  + $loc"
  }
}
Gravar $sm $xml

Write-Host '>> Enviando' -ForegroundColor Magenta
$arquivos = @('index.html','sitemap.xml','rastreio.js') + ($Paginas.Keys | ForEach-Object { "$_.html" })
git add -- $arquivos
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host 'Nada novo para publicar.'; return }
git commit -m 'Paginas de loiro platinado e cilios/sobrancelha + links entre servicos'
git push
if ($LASTEXITCODE) { throw 'git push falhou.' }

Write-Host '>> Conferindo no ar (aguarde ate 3 min)' -ForegroundColor Magenta
foreach ($s in $Paginas.Keys) {
  $u = "$Dominio/$s"; $ok = $false
  for ($t=1; $t -le 18 -and -not $ok; $t++) { try { if ((Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 15).StatusCode -eq 200) { $ok = $true } } catch { Start-Sleep 10 } }
  if ($ok) { Write-Host "  no ar  $u" -ForegroundColor Green } else { Write-Host "  falhou $u" -ForegroundColor Red }
}
"$Dominio/loiro-platinado-coqueiros-florianopolis`n$Dominio/cilios-sobrancelha-coqueiros-florianopolis" | Set-Clipboard
Write-Host "`nAs 2 URLs novas foram copiadas. Peca a indexacao delas no Search Console." -ForegroundColor Green
