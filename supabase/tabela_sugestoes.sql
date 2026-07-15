-- Redesign v1.4 — Fase 4.3
-- Sugestões: o POS insere (anon) o texto livre do cliente. O admin (Control)
-- lê, marca (importante), e arquiva.

create table if not exists public.sugestoes (
  id            uuid primary key default gen_random_uuid(),
  machine_id    text,
  nif           text,
  cliente_id    uuid references public.clientes(id) on delete set null,
  texto         text not null,
  criado_em     timestamptz not null default now(),
  lida          boolean not null default false,
  marcada       boolean not null default false,
  arquivada     boolean not null default false
);

create index if not exists sugestoes_por_ler_idx
  on public.sugestoes (criado_em desc) where lida = false and arquivada = false;

alter table public.sugestoes enable row level security;

create policy sugestoes_insert_anon on public.sugestoes
  for insert to anon with check (true);
create policy sugestoes_admin_read on public.sugestoes
  for select to authenticated using (true);
create policy sugestoes_admin_update on public.sugestoes
  for update to authenticated using (true);
