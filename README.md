# Radar Salão de Beleza (Oceanus / IntentRadar)

Primeiro nicho do IntentRadar aplicado a um cliente real: o **Morgana Silveira Studio de Beleza** (Coqueiros, Florianópolis).

**A ideia em uma frase:** o salão aparece no Google e nas IAs para quem já procura o serviço, essa pessoa chama no WhatsApp, e tudo é medido.

## Fluxo

```
Busca no Google / IA ──> Página SEO/GEO (serviço + Coqueiros)
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
   Botão WhatsApp [CODIGO]              Formulário do site
   rastreio.js -> oceanus-ai            morgana-lead -> nexushive
   (whatsapp_cliques)                   (morgana_contatos) + e-mail para a Ana
              │                               │
              ▼                               ▼
   Ana marca o agendamento              Listas CSV (só com consentimento)
   em /agenda-ana (PIN)                 transmissão, remarketing, Meta Ads
```

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `site/` | Cópia das páginas publicadas no repo `Morgana-silveira`: 5 páginas de serviço, `rastreio.js` e `agenda-ana.html` |
| `dashboard/` | Painel DEMO do radar (sinais sintéticos, plano de páginas SEO/GEO) |
| `scripts/` | PowerShell para publicar páginas, exportar listas e instalar o relatório semanal do Search Console |
| `supabase/oceanus-ai/migrations/` | Tabelas de cliques, agendamentos e Search Console, funções da agenda da Ana |
| `supabase/nexushive/functions/` | Edge functions do salão: formulário (`morgana-lead`), contador (`morgana-clique`), WhatsApp (`morgana-whatsapp-webhook`) |

## Páginas no ar

- /mechas-coqueiros-florianopolis — código `[MECHAS-COQUEIROS]`
- /loiro-platinado-coqueiros-florianopolis — `[PLATINADO-COQUEIROS]`
- /unhas-fibra-gel-coqueiros-florianopolis — `[UNHAS-COQUEIROS]`
- /progressiva-coqueiros-florianopolis — `[PROGRESSIVA-COQUEIROS]`
- /cilios-sobrancelha-coqueiros-florianopolis — `[CILIOS-COQUEIROS]`
- /agenda-ana (noindex, protegida por PIN)

## Pontos de atenção

- **nexushive:** o schema padrão da Data API não é `public`. Todo cliente precisa usar `db: { schema: "public" }` (supabase-js) ou o header `Accept-Profile: public` (REST).
- **Chaves secretas** (`sb_secret_...`) só em ambiente protegido. No PowerShell 5, use `-UserAgent` próprio, senão o Supabase bloqueia como se fosse navegador.
- **Secrets da função `morgana-lead`:** `RESEND_API_KEY`, `AVISO_EMAIL` (e, opcional, `CALLMEBOT_PHONE`/`CALLMEBOT_APIKEY`).
- **PIN da agenda:** não fica no repositório. Veja o comentário em `002_agenda_ana_pin.sql` para trocar.
- **LGPD:** listas de campanha só com quem marcou a caixa de promoções; `SAIR` no WhatsApp remove na hora.
- Existem dois contadores de clique (antigo em nexushive, novo em oceanus-ai). Unificar depois.

## Próximos passos

1. Após 2 a 3 semanas, ler Search Console (Desempenho) e a agenda da Ana.
2. Ligar o radar a dados reais (`scripts/instalar-radar.ps1`).
3. Decidir novas páginas por dados, não por palpite.
