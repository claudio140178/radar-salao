"""Radar semanal: puxa buscas reais do Search Console para o Supabase e mostra o resumo.
Precisa de: GSC_KEY_FILE (JSON da conta de servico) e SUPABASE_SERVICE_KEY (variaveis de ambiente)."""
import os, datetime, requests
from urllib.parse import quote
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession

SITE = 'https://morganasilveirastudiodebeleza.online/'
NOME = 'morganasilveirastudiodebeleza.online'
SB = 'https://bktxduncdwklopfkclxk.supabase.co/rest/v1'
SB_KEY = os.environ['SUPABASE_SERVICE_KEY']
KEY_FILE = os.environ.get('GSC_KEY_FILE', r'C:\Users\claud\radar\gsc-key.json')
H = {'apikey': SB_KEY, 'Content-Type': 'application/json'}

creds = service_account.Credentials.from_service_account_file(
    KEY_FILE, scopes=['https://www.googleapis.com/auth/webmasters.readonly'])
gsc = AuthorizedSession(creds)
fim = datetime.date.today() - datetime.timedelta(days=3)
ini = fim - datetime.timedelta(days=27)
url = f'https://www.googleapis.com/webmasters/v3/sites/{quote(SITE, safe="")}/searchAnalytics/query'

linhas, start = [], 0
while True:
    r = gsc.post(url, json={'startDate': str(ini), 'endDate': str(fim),
                            'dimensions': ['date', 'page', 'query'], 'rowLimit': 25000, 'startRow': start})
    r.raise_for_status()
    lote = r.json().get('rows', [])
    linhas += lote
    if len(lote) < 25000:
        break
    start += 25000

dados = [{'data': x['keys'][0], 'site': NOME, 'pagina': x['keys'][1], 'consulta': x['keys'][2],
          'cliques': int(x['clicks']), 'impressoes': int(x['impressions']),
          'ctr': x['ctr'], 'posicao': x['position']} for x in linhas]
for i in range(0, len(dados), 1000):
    rr = requests.post(f'{SB}/search_console_buscas',
                       headers={**H, 'Prefer': 'resolution=merge-duplicates,return=minimal'},
                       json=dados[i:i + 1000])
    rr.raise_for_status()
print(f'Search Console: {len(dados)} linhas de {ini} a {fim}')

# Resumo: buscas com mais impressoes e cliques no WhatsApp por pagina
tot = {}
for d in dados:
    t = tot.setdefault(d['consulta'], [0, 0])
    t[0] += d['impressoes']; t[1] += d['cliques']
print('\nBuscas que mais mostraram o site (28 dias):')
for q, (imp, cl) in sorted(tot.items(), key=lambda kv: -kv[1][0])[:15]:
    print(f'  {imp:>5} impressoes  {cl:>3} cliques  {q}')

r = requests.get(f'{SB}/radar_resumo_semanal?site=eq.{NOME}&order=semana.desc&limit=30', headers=H)
r.raise_for_status()
print('\nCliques no WhatsApp por pagina (ultimas semanas):')
for x in r.json():
    print(f"  semana {x['semana']}  {x['ref']:<24} {x['cliques_whatsapp']:>3} cliques  {x['agendamentos']:>3} agendamentos")
