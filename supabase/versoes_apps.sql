-- Auto-update (task #100, parte Control).
-- Catálogo de versões disponíveis por app. A Edge Function `versao-mais-recente`
-- devolve a versão activa com build_number mais alto para uma dada app; o cliente
-- compara com o seu build local e mostra banner se houver actualização.
-- Aplicado no projecto oefqbkhioncakojipqyx via MCP (migration versoes_apps).
-- Este ficheiro consolida o estado final para versionamento (aditivo; idempotente).
--
-- NOTA de numeração: o Control shippa 1.7.0 como build_number 24 (o build 23 já
-- foi ocupado pela release 1.6.3). O Android exige versionCode estritamente maior
-- para actualizar, por isso build_number é a fonte de verdade da comparação —
-- nunca a string de versão.

create table if not exists public.versoes_apps (
  id uuid primary key default gen_random_uuid(),
  app text not null check (app in ('pos', 'control', 'punho')),
  versao text not null,
  build_number integer not null,
  url_download text not null,
  data_lancamento timestamptz not null default now(),
  obrigatoria boolean not null default false,
  notas_lancamento text,
  activa boolean not null default true,
  plataforma text not null default 'all'
    check (plataforma in ('all', 'windows', 'android', 'ios')),
  unique (app, build_number, plataforma)
);

-- Alterações aditivas para BDs já criadas antes destas colunas/constraints.
-- Idempotentes. Reflectem o estado real observado no projecto
-- oefqbkhioncakojipqyx em 2026-07-27.
alter table public.versoes_apps
  drop constraint if exists versoes_apps_app_check;
alter table public.versoes_apps
  add constraint versoes_apps_app_check
    check (app in ('pos', 'control', 'punho'));

alter table public.versoes_apps
  add column if not exists plataforma text not null default 'all';
alter table public.versoes_apps
  drop constraint if exists versoes_apps_plataforma_check;
alter table public.versoes_apps
  add constraint versoes_apps_plataforma_check
    check (plataforma in ('all', 'windows', 'android', 'ios'));

comment on table public.versoes_apps is 'Catálogo de versões dos apps WashInvoice (POS Windows) e WashInvoiceControl (Android). A Edge Function versao-mais-recente devolve a versão activa com build_number mais alto. build_number é a chave de comparação (não a string de versão).';

create index if not exists idx_versoes_apps_app_activa
  on public.versoes_apps(app, build_number desc) where activa = true;

-- RLS: mesmo modelo das outras tabelas. A Edge Function lê com service_role;
-- authenticated pode ler o catálogo (sem segredos — os URLs são releases públicos).
alter table public.versoes_apps enable row level security;

drop policy if exists service_role_versoes_apps on public.versoes_apps;
create policy service_role_versoes_apps
  on public.versoes_apps as permissive for all
  to service_role using (true) with check (true);

drop policy if exists authenticated_read_versoes_apps on public.versoes_apps;
create policy authenticated_read_versoes_apps
  on public.versoes_apps as permissive for select
  to authenticated using (activa = true);

-- Seed da versão actual do Control. O url_download é PLACEHOLDER: o Cesar cria o
-- release no GitHub (tag control-1.7.0) e actualiza este URL via SQL antes de o
-- APK chegar às mãos de clientes. Ver docs/negocio/auto_update.md.
insert into public.versoes_apps (app, versao, build_number, url_download, obrigatoria, activa)
values
  ('control', '1.7.0', 24,
   'https://github.com/CesarM78/washinvoice-releases/releases/download/control-1.7.0/WashInvoiceControl_v1.7.0.apk',
   false, true)
on conflict (app, build_number) do nothing;
