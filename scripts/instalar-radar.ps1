# Instala o radar semanal: dependencias, chaves e tarefa agendada (segunda 9h)
$ErrorActionPreference = 'Stop'
$dir = "$env:USERPROFILE\radar"
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'radar_semanal.py') $dir -Force
$py = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $py) { throw 'Python nao encontrado. Instale o Python e rode de novo.' }
& $py -m pip install --quiet --upgrade google-auth requests
if (-not (Test-Path "$dir\gsc-key.json")) {
  $j = Read-Host 'Caminho do arquivo JSON da conta de servico do Google (arraste o arquivo para ca)'
  Copy-Item $j.Trim('"') "$dir\gsc-key.json" -Force
}
if (-not [Environment]::GetEnvironmentVariable('SUPABASE_SERVICE_KEY','User')) {
  $s = Read-Host 'Cole a secret key do Supabase (projeto oceanus-ai)'
  [Environment]::SetEnvironmentVariable('SUPABASE_SERVICE_KEY', $s.Trim(), 'User')
  $env:SUPABASE_SERVICE_KEY = $s.Trim()
}
[Environment]::SetEnvironmentVariable('GSC_KEY_FILE', "$dir\gsc-key.json", 'User')
$env:GSC_KEY_FILE = "$dir\gsc-key.json"
$acao = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -Command `"& '$py' '$dir\radar_semanal.py' *> '$dir\relatorio.txt'`""
$gatilho = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 9am
Register-ScheduledTask -TaskName 'Radar Salao Semanal' -Action $acao -Trigger $gatilho -Force | Out-Null
Write-Host 'Tarefa criada: toda segunda as 9h. Rodando agora para testar...' -ForegroundColor Green
& $py "$dir\radar_semanal.py"
Write-Host "`nRelatorio semanal fica em $dir\relatorio.txt" -ForegroundColor Green
