# Gera CSVs das listas do Studio Morgana Silveira (somente contatos com consentimento)
# Le a tabela morgana_contatos do Supabase nexushive. O schema padrao da Data API desse projeto nao e public,
# por isso o header Accept-Profile: public e obrigatorio. User-Agent proprio evita o bloqueio de "chave secreta no navegador".
$ErrorActionPreference = 'Stop'
$api = 'https://jubiancxpdbxmxrlepqu.supabase.co/rest/v1'
$key = [Environment]::GetEnvironmentVariable('NEXUSHIVE_SERVICE_KEY','User')
if (-not $key) { $key = (Read-Host 'Cole a secret key do Supabase nexushive').Trim(); [Environment]::SetEnvironmentVariable('NEXUSHIVE_SERVICE_KEY',$key,'User') }
$h = @{ apikey = $key; 'Accept-Profile' = 'public' }; $ua = 'exportar-listas/1.0'
$dir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'morgana-listas'
New-Item -ItemType Directory -Force $dir | Out-Null
$hoje = Get-Date -Format 'yyyy-MM-dd'
$c = @(Invoke-RestMethod "$api/morgana_contatos?select=nome,telefone,servico_interesse,ultimo_contato,consentimento_em&consentimento_marketing=eq.true&opt_out_em=is.null&order=ultimo_contato.desc" -Headers $h -UserAgent $ua)
$c | Export-Csv "$dir\lista-transmissao-$hoje.csv" -NoTypeInformation -Encoding UTF8
$remk = $c | ForEach-Object {
  $dias = if ($_.ultimo_contato) { ((Get-Date) - [datetime]::Parse($_.ultimo_contato)).TotalDays } else { 999 }
  $s = "$($_.servico_interesse)"
  $seg = if ($s -match 'mecha|loiro|platinado|colora' -and $dias -gt 45) { 'retoque_cor' }
         elseif ($s -match 'gel|fibra|f1|cilios|c.lios' -and $dias -gt 21) { 'manutencao_unha_cilios' }
         elseif ($dias -gt 90) { 'sumida_90d' } else { 'ativa' }
  [pscustomobject]@{ nome=$_.nome; telefone=$_.telefone; servico_interesse=$s; ultimo_contato=$_.ultimo_contato; segmento=$seg }
}
$remk | Export-Csv "$dir\remarketing-$hoje.csv" -NoTypeInformation -Encoding UTF8
$c | ForEach-Object { [pscustomobject]@{ phone=($_.telefone -replace '\D',''); fn=(("$($_.nome)" -split ' ')[0]); ct='florianopolis'; st='sc'; country='br' } } | Export-Csv "$dir\meta-ads-publico-$hoje.csv" -NoTypeInformation -Encoding UTF8
Write-Host "Lista de transmissao: $($c.Count) contatos" -ForegroundColor Green
$remk | Group-Object segmento | ForEach-Object { Write-Host ("  {0}: {1}" -f $_.Name, $_.Count) }
Write-Host "Arquivos em: $dir"
Write-Host 'So entram contatos que aceitaram promocoes. Quem responder SAIR deve ser removido.' -ForegroundColor Yellow
Start-Process $dir
