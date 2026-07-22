-- Sprint webservice AT — comunicação de séries (task #89).
-- Aplicado no projecto oefqbkhioncakojipqyx via MCP em 2026-07-22, em 3 migrations:
--   series_webservice_at_schema, helper_ler_secret_at_vault, allowlist_at_ws_teste_secrets.
-- Este ficheiro consolida o estado final para versionamento (aditivo; idempotente).

-- ── licencas: ATCUD-CV + credenciais AT do cliente ──────────────────────────
alter table public.licencas
  add column if not exists codigo_validacao_at text,
  add column if not exists data_comunicacao_serie timestamptz,
  add column if not exists at_username text,
  add column if not exists at_password_cifrada text;

comment on column public.licencas.codigo_validacao_at is 'ATCUD-CV recebido do webservice AT quando a série foi comunicada. Ex: J6SHZMK5.';
comment on column public.licencas.data_comunicacao_serie is 'Quando a série foi comunicada à AT via webservice.';
comment on column public.licencas.at_username is 'Sub-utilizador AT do contribuinte (formato NIF/N). Introduzido uma vez no setup.';
comment on column public.licencas.at_password_cifrada is 'Password AT cifrada com AES-GCM (chave do servidor vault:at_cred_enc_key), base64 de nonce||ciphertext||tag. Nunca plaintext, nunca cifrada com a chave pública AT.';

-- ── series_comunicadas: historial das comunicações (debug + audit) ──────────
create table if not exists public.series_comunicadas (
  id uuid primary key default gen_random_uuid(),
  licenca_id uuid not null references public.licencas(id) on delete cascade,
  machine_id text not null,
  serie text not null,
  tipo_doc text not null,
  numero_inicial integer not null default 1,
  data_inicio date not null,
  codigo_validacao text,
  resposta_at_raw jsonb,
  erro text,
  ambiente text not null default 'testes' check (ambiente in ('testes', 'producao')),
  feito_por text,
  created_at timestamptz not null default now()
);

comment on table public.series_comunicadas is 'Historial de comunicações de séries à AT via webservice (task #89). Escrito por service_role (Edge Function comunicar-serie); lido por authenticated com is_admin() no Control.';

create index if not exists idx_series_comunicadas_licenca
  on public.series_comunicadas(licenca_id, created_at desc);

-- RLS: mesmo modelo do licencas (service_role tudo; authenticated+is_admin() leitura).
alter table public.series_comunicadas enable row level security;

drop policy if exists service_role_series_comunicadas on public.series_comunicadas;
create policy service_role_series_comunicadas
  on public.series_comunicadas as permissive for all
  to service_role using (true) with check (true);

drop policy if exists authenticated_admin_read_series_comunicadas on public.series_comunicadas;
create policy authenticated_admin_read_series_comunicadas
  on public.series_comunicadas as permissive for select
  to authenticated using (is_admin());

-- ── Helper: Edge Functions (service_role) lêem secrets do Vault ─────────────
-- O schema `vault` não é exposto via PostgREST; esta função security definer
-- (dona = postgres) lê a view decrypted_secrets, com allowlist dos nomes AT.
create or replace function public.ler_secret_at(p_nome text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v text;
begin
  if p_nome not in (
    'at_cert_teste_pfx_b64',
    'at_chave_publica_b64',
    'at_cert_teste_password',
    'at_cred_enc_key',
    'at_ws_username_teste',
    'at_ws_password_teste'
  ) then
    raise exception 'secret nao permitido: %', p_nome;
  end if;
  select decrypted_secret into v
    from vault.decrypted_secrets
    where name = p_nome
    limit 1;
  return v;
end;
$$;

revoke all on function public.ler_secret_at(text) from public;
revoke all on function public.ler_secret_at(text) from anon;
revoke all on function public.ler_secret_at(text) from authenticated;
grant execute on function public.ler_secret_at(text) to service_role;
