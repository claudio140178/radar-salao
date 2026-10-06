-- Pagina agenda-ana: a Ana registra agendamentos com PIN (hash bcrypt), com bloqueio apos 10 erros em 15 min.
-- O PIN NAO fica no repositorio. Para definir ou trocar:
--   update public.radar_config set pin_hash = extensions.crypt('NOVO_PIN', extensions.gen_salt('bf'))
--   where site = 'morganasilveirastudiodebeleza.online';
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.radar_config (site text primary key, pin_hash text not null);
alter table public.radar_config enable row level security;

create table if not exists public.radar_pin_falhas (
  id bigint generated always as identity primary key,
  criado_em timestamptz not null default now(),
  site text not null
);
alter table public.radar_pin_falhas enable row level security;

create or replace function public._pin_ok(p_site text, p_pin text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
declare ok boolean;
begin
  if (select count(*) from radar_pin_falhas where site = p_site and criado_em > now() - interval '15 minutes') >= 10 then
    raise exception 'Muitas tentativas. Aguarde 15 minutos.';
  end if;
  select exists (select 1 from radar_config where site = p_site and pin_hash = crypt(p_pin, pin_hash)) into ok;
  if not ok then insert into radar_pin_falhas (site) values (p_site); end if;
  return ok;
end $$;
revoke all on function public._pin_ok(text, text) from public, anon, authenticated;

-- PIN errado retorna json (sem exception) para a falha registrada nao sofrer rollback
create or replace function public.registrar_agendamento(p_pin text, p_ref text, p_servico text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare s text := 'morganasilveirastudiodebeleza.online';
begin
  if not _pin_ok(s, p_pin) then return json_build_object('ok', false, 'erro', 'PIN invalido'); end if;
  if p_ref !~ '^[A-Z0-9-]{2,40}$' then return json_build_object('ok', false, 'erro', 'ref invalida'); end if;
  insert into agendamentos_confirmados (site, ref, servico) values (s, p_ref, left(p_servico, 80));
  return json_build_object('ok', true);
end $$;

create or replace function public.desfazer_ultimo_agendamento(p_pin text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare s text := 'morganasilveirastudiodebeleza.online'; v_id bigint;
begin
  if not _pin_ok(s, p_pin) then return json_build_object('ok', false, 'erro', 'PIN invalido'); end if;
  select id into v_id from agendamentos_confirmados
   where site = s and criado_em > now() - interval '1 day' order by id desc limit 1;
  if v_id is null then return json_build_object('ok', false); end if;
  delete from agendamentos_confirmados where id = v_id;
  return json_build_object('ok', true);
end $$;

create or replace function public.resumo_semana(p_pin text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare s text := 'morganasilveirastudiodebeleza.online';
begin
  if not _pin_ok(s, p_pin) then return json_build_object('ok', false, 'erro', 'PIN invalido'); end if;
  return json_build_object('ok', true,
    'agendamentos', (select coalesce(json_object_agg(ref, n), '{}'::json) from
        (select ref, count(*) n from agendamentos_confirmados where site = s and criado_em >= date_trunc('week', now()) group by ref) a),
    'cliques', (select coalesce(json_object_agg(ref, n), '{}'::json) from
        (select ref, count(*) n from whatsapp_cliques where site = s and criado_em >= date_trunc('week', now()) group by ref) c));
end $$;

revoke execute on function public.registrar_agendamento(text,text,text) from public, authenticated;
revoke execute on function public.desfazer_ultimo_agendamento(text) from public, authenticated;
revoke execute on function public.resumo_semana(text) from public, authenticated;
grant execute on function public.registrar_agendamento(text,text,text) to anon;
grant execute on function public.desfazer_ultimo_agendamento(text) to anon;
grant execute on function public.resumo_semana(text) to anon;
