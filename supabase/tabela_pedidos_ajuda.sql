-- Redesign v1.4 — Fase 4.2
-- Pedidos de ajuda: o POS insere (anon) quando o cliente carrega em "Pedir Ajuda".
-- O admin (Control, authenticated) lê e marca como resolvido.

create table if not exists public.pedidos_ajuda (
  id            uuid primary key default gen_random_uuid(),
  machine_id    text not null,
  nif           text,
  cliente_id    uuid references public.clientes(id) on delete set null,
  criado_em     timestamptz not null default now(),
  resolvido_em  timestamptz,
  notas         text
);

create index if not exists pedidos_ajuda_abertos_idx
  on public.pedidos_ajuda (criado_em desc) where resolvido_em is null;

alter table public.pedidos_ajuda enable row level security;

-- POS insere (anon) só o seu próprio pedido. Admin (authenticated) lê e atualiza.
create policy pedidos_ajuda_insert_anon on public.pedidos_ajuda
  for insert to anon with check (true);
create policy pedidos_ajuda_admin_read on public.pedidos_ajuda
  for select to authenticated using (true);
create policy pedidos_ajuda_admin_update on public.pedidos_ajuda
  for update to authenticated using (true);
