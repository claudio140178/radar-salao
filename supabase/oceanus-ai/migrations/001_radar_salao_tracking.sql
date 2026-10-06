-- Projeto Supabase: oceanus-ai (bktxduncdwklopfkclxk)
-- Cliques no WhatsApp das paginas SEO/GEO (sem dados pessoais), agendamentos e buscas do Search Console
create table public.whatsapp_cliques (
  id bigint generated always as identity primary key,
  criado_em timestamptz not null default now(),
  site text not null check (char_length(site) <= 80),
  pagina text not null check (char_length(pagina) <= 120),
  ref text not null check (char_length(ref) <= 40),
  servico text check (char_length(servico) <= 80),
  origem text check (char_length(origem) <= 80),
  dispositivo text check (dispositivo in ('mobile','desktop'))
);
create index on public.whatsapp_cliques (site, criado_em);
alter table public.whatsapp_cliques enable row level security;
create policy "site registra clique" on public.whatsapp_cliques
  for insert to anon with check (site = 'morganasilveirastudiodebeleza.online');

create table public.agendamentos_confirmados (
  id bigint generated always as identity primary key,
  criado_em timestamptz not null default now(),
  site text not null,
  ref text not null,
  servico text
);
alter table public.agendamentos_confirmados enable row level security;

create table public.search_console_buscas (
  data date not null,
  site text not null,
  pagina text not null,
  consulta text not null,
  cliques int not null default 0,
  impressoes int not null default 0,
  ctr numeric,
  posicao numeric,
  primary key (data, site, pagina, consulta)
);
alter table public.search_console_buscas enable row level security;

create view public.radar_resumo_semanal with (security_invoker = true) as
with c as (
  select date_trunc('week', criado_em)::date semana, site, ref, count(*) cliques_whatsapp
  from public.whatsapp_cliques group by 1,2,3),
a as (
  select date_trunc('week', criado_em)::date semana, site, ref, count(*) agendamentos
  from public.agendamentos_confirmados group by 1,2,3)
select coalesce(c.semana,a.semana) semana, coalesce(c.site,a.site) site, coalesce(c.ref,a.ref) ref,
       coalesce(c.cliques_whatsapp,0) cliques_whatsapp, coalesce(a.agendamentos,0) agendamentos
from c full join a on a.semana=c.semana and a.site=c.site and a.ref=c.ref;
