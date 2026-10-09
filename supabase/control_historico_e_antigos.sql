-- Histórico do Control (o que se tratou, quando e como) e clientes antigos
-- (licenças que o Cesar negou: saem do Agora e ficam em Clientes › Antigos).
-- Só o admin lê e escreve. Aditivo: não toca em nenhuma tabela existente.

create table if not exists public.control_historico (
  id         uuid primary key default gen_random_uuid(),
  criado_em  timestamptz not null default now(),
  tipo       text not null,
  app        text,
  titulo     text not null,
  pedido     text,
  accao      text not null,
  machine_id text
);
create index if not exists control_historico_criado_idx
  on public.control_historico (criado_em desc);

alter table public.control_historico enable row level security;
revoke all on public.control_historico from anon, authenticated;
grant select, insert on public.control_historico to authenticated;
drop policy if exists control_historico_admin_select on public.control_historico;
create policy control_historico_admin_select on public.control_historico
  for select to authenticated using (public.is_admin());
drop policy if exists control_historico_admin_insert on public.control_historico;
create policy control_historico_admin_insert on public.control_historico
  for insert to authenticated with check (public.is_admin());

create table if not exists public.clientes_antigos (
  machine_id text primary key,
  app        text,
  titulo     text,
  desde      timestamptz not null default now()
);

alter table public.clientes_antigos enable row level security;
revoke all on public.clientes_antigos from anon, authenticated;
grant select, insert, delete on public.clientes_antigos to authenticated;
drop policy if exists clientes_antigos_admin_all on public.clientes_antigos;
create policy clientes_antigos_admin_all on public.clientes_antigos
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
