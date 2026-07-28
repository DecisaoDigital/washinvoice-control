-- Extensão do catálogo de atualizações para o Punho.
-- Executar depois de versoes_apps.sql no mesmo projeto Supabase do Control.

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

alter table public.versoes_apps
  drop constraint if exists versoes_apps_app_build_number_key;
create unique index if not exists versoes_apps_app_plataforma_build_unique
  on public.versoes_apps (app, plataforma, build_number);

comment on table public.versoes_apps is
  'Catálogo de versões do POS, WashInvoice Control e Punho. A Edge Function versao-mais-recente compara build_number.';

-- Antes da primeira distribuição, inserir a versão real e URL de download:
-- insert into public.versoes_apps
--   (app, versao, build_number, url_download, obrigatoria, notas_lancamento, activa)
-- values
--   ('punho', '1.0.0', 1, 'https://.../PunhoSetup.exe', false, 'Primeira versão', true);
