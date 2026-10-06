# publicar-paginas.ps1
# Publica as paginas SEO/GEO no site morganasilveirastudiodebeleza.online
# Uso:
#   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\publicar-paginas.ps1"
# Opcoes:
#   -Repo   caminho do repositorio (padrao: Documentos\Morgana-silveira; clona se nao existir)
#   -Origem pasta onde estao os .html baixados (padrao: Downloads)
#   -SemPush  faz tudo, menos o push (para revisar antes)

param(
  [string]$Repo   = "$env:USERPROFILE\Documents\Morgana-silveira",
  [string]$Origem = "$env:USERPROFILE\Downloads",
  [switch]$SemPush
)

$ErrorActionPreference = 'Stop'
$Dominio = 'https://morganasilveirastudiodebeleza.online'
$Paginas = @(
  @{ Arquivo = 'mechas-coqueiros-florianopolis.html';          Texto = 'Mechas e loiro em Coqueiros' },
  @{ Arquivo = 'unhas-fibra-gel-coqueiros-florianopolis.html'; Texto = 'Unhas em fibra e gel em Coqueiros' },
  @{ Arquivo = 'progressiva-coqueiros-florianopolis.html';     Texto = 'Progressiva em Coqueiros' }
)

$Utf8 = New-Object System.Text.UTF8Encoding($false)
function Ler($p)     { [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) }
function Gravar($p,$t){ [IO.File]::WriteAllText($p, $t, $Utf8) }
function Passo($m)   { Write-Host "`n>> $m" -ForegroundColor Magenta }
function Slug($a)    { [IO.Path]::GetFileNameWithoutExtension($a) }

# 1. Git e repositorio
Passo 'Verificando git e repositorio'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git nao encontrado. Instale o Git for Windows.' }
if (-not (Test-Path (Join-Path $Repo '.git'))) {
  Write-Host "  Repositorio nao encontrado em $Repo. Clonando..."
  git clone https://github.com/claudio140178/Morgana-silveira.git $Repo
  if ($LASTEXITCODE) { throw 'Falha ao clonar o repositorio.' }
}
Set-Location $Repo
git pull --ff-only
if ($LASTEXITCODE) { throw 'git pull falhou. Salve ou descarte alteracoes locais e rode de novo.' }

# 2. Copia as paginas (pega a versao mais recente, mesmo se o navegador renomeou para "(1)")
Passo 'Copiando paginas'
foreach ($p in $Paginas) {
  $base = Slug $p.Arquivo
  $src = Get-ChildItem -Path $Origem -Filter "$base*.html" -ErrorAction SilentlyContinue |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $src) { throw "Nao achei $($p.Arquivo) em $Origem. Baixe os arquivos e rode de novo." }
  Copy-Item $src.FullName (Join-Path $Repo $p.Arquivo) -Force
  Write-Host "  ok  $($p.Arquivo)  (de $($src.Name))"
}

# 3. vercel.json com cleanUrls (URL sem .html)
Passo 'Configurando vercel.json'
$vj = Join-Path $Repo 'vercel.json'
if (Test-Path $vj) {
  $cfg = Ler $vj | ConvertFrom-Json
  if ($cfg.PSObject.Properties.Name -contains 'cleanUrls') { $cfg.cleanUrls = $true }
  else { $cfg | Add-Member -NotePropertyName cleanUrls -NotePropertyValue $true }
  Gravar $vj (($cfg | ConvertTo-Json -Depth 20) + "`n")
  Write-Host '  cleanUrls ativado no vercel.json existente'
} else {
  Gravar $vj "{`n  `"cleanUrls`": true`n}`n"
  Write-Host '  vercel.json criado'
}

# 4. sitemap.xml
Passo 'Atualizando sitemap.xml'
$sm = Join-Path $Repo 'sitemap.xml'
$hoje = Get-Date -Format 'yyyy-MM-dd'
if (-not (Test-Path $sm)) {
  Gravar $sm "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`">`n  <url>`n    <loc>$Dominio/</loc>`n    <lastmod>$hoje</lastmod>`n  </url>`n</urlset>`n"
  Write-Host '  sitemap.xml criado'
}
$xml = Ler $sm
foreach ($p in $Paginas) {
  $loc = "$Dominio/" + (Slug $p.Arquivo)
  if ($xml -notmatch [regex]::Escape("<loc>$loc</loc>")) {
    $entrada = "  <url>`n    <loc>$loc</loc>`n    <lastmod>$hoje</lastmod>`n    <changefreq>monthly</changefreq>`n    <priority>0.8</priority>`n  </url>`n</urlset>"
    $xml = $xml.Replace('</urlset>', $entrada)
    Write-Host "  + $loc"
  } else { Write-Host "  ja existe $loc" }
}
Gravar $sm $xml

$rb = Join-Path $Repo 'robots.txt'
if ((Test-Path $rb) -and ((Ler $rb) -notmatch 'Sitemap:')) {
  Gravar $rb ((Ler $rb).TrimEnd() + "`nSitemap: $Dominio/sitemap.xml`n")
  Write-Host '  robots.txt agora aponta para o sitemap'
}

# 5. Links na pagina principal
Passo 'Colocando links na pagina principal'
$idx = Join-Path $Repo 'index.html'
if (-not (Test-Path $idx)) { Write-Warning 'index.html nao encontrado. Links nao inseridos.' }
else {
  $html = Ler $idx
  if ($html -match 'paginas-seo') { Write-Host '  links ja estavam na home' }
  else {
    $itens = ($Paginas | ForEach-Object { "    <li><a href=`"/$(Slug $_.Arquivo)`">$($_.Texto)</a></li>" }) -join "`n"
    $bloco = @"
<!-- paginas-seo -->
<section id="saiba-mais" style="max-width:1080px;margin:0 auto;padding:40px 20px">
  <h2>Saiba mais</h2>
  <ul style="list-style:none;padding:0;margin:16px 0 0;display:flex;flex-wrap:wrap;gap:12px 28px">
$itens
  </ul>
</section>
<!-- /paginas-seo -->
"@
    $pos = $html.IndexOf('</main>')
    if ($pos -lt 0) { $pos = $html.IndexOf('<footer') }
    if ($pos -lt 0) { Write-Warning 'Nao achei </main> nem <footer> no index.html. Links nao inseridos.' }
    else {
      Gravar $idx ($html.Insert($pos, "$bloco`n"))
      Write-Host '  bloco "Saiba mais" com os 3 links inserido'
    }
  }
}

# 6. Commit e push
Passo 'Enviando para o GitHub'
$arquivos = @('vercel.json','sitemap.xml','index.html') + ($Paginas | ForEach-Object { $_.Arquivo })
if (Test-Path $rb) { $arquivos += 'robots.txt' }
git add -- $arquivos
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host '  Nada novo para publicar.' }
else {
  git commit -m 'Paginas SEO/GEO em Coqueiros: mechas, unhas e progressiva'
  if ($SemPush) { Write-Host '  Commit feito. Push pulado (-SemPush). Rode "git push" quando revisar.' -ForegroundColor Yellow; return }
  git push
  if ($LASTEXITCODE) { throw 'git push falhou. Verifique o login do GitHub.' }
}

# 7. Espera a Vercel e confere se as paginas estao no ar
Passo 'Aguardando a Vercel publicar (ate 3 min por pagina)'
$urls = @("$Dominio/") + ($Paginas | ForEach-Object { "$Dominio/" + (Slug $_.Arquivo) })
$falhas = 0
foreach ($u in $urls) {
  $ok = $false
  for ($t = 1; $t -le 18 -and -not $ok; $t++) {
    try {
      $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 15
      if ($r.StatusCode -eq 200) { $ok = $true }
    } catch { Start-Sleep -Seconds 10 }
  }
  if ($ok) { Write-Host "  no ar  $u" -ForegroundColor Green }
  else     { Write-Host "  falhou $u" -ForegroundColor Red; $falhas++ }
}

# 8. Search Console (passo manual)
Passo 'Indexacao no Google'
$urls | Set-Clipboard
Write-Host '  As URLs foram copiadas. No Search Console (conta studioananeves@gmail.com):'
Write-Host '  cole cada URL em "Inspecionar URL" e clique em "Solicitar indexacao".'
Write-Host '  Depois, em Sitemaps, reenvie sitemap.xml.'
Start-Process 'https://search.google.com/search-console'

if ($falhas) { Write-Warning "$falhas pagina(s) nao responderam. Confira o deploy na Vercel." }
else { Write-Host "`nTudo publicado." -ForegroundColor Green }
