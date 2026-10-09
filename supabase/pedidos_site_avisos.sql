-- Avisos de pedidos novos do site decisaodigital.pt (envelope no Control).
-- SÓ a referência (6 caracteres): nome, telefone e notas ficam no i9, nunca aqui.
-- O i9 insere com a chave de serviço (ignora RLS); o Control (admin) lê e marca como vista.
create table if not exists public.pedidos_site_avisos (
  ref       text primary key check (ref ~ '^[2-9A-HJ-NP-Z]{6}$'),
  criado_em timestamptz not null default now(),
  visto_em  timestamptz null
);

create index if not exists pedidos_site_avisos_por_ver_idx
  on public.pedidos_site_avisos (criado_em desc) where visto_em is null;

alter table public.pedidos_site_avisos enable row level security;

revoke all on public.pedidos_site_avisos from anon, authenticated;
grant select, update (visto_em) on public.pedidos_site_avisos to authenticated;

drop policy if exists pedidos_site_avisos_admin_select on public.pedidos_site_avisos;
create policy pedidos_site_avisos_admin_select on public.pedidos_site_avisos
  for select to authenticated using (public.is_admin());

drop policy if exists pedidos_site_avisos_admin_update on public.pedidos_site_avisos;
create policy pedidos_site_avisos_admin_update on public.pedidos_site_avisos
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
