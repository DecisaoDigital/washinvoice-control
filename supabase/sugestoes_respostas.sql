-- Respostas do César às sugestões dos clientes (POS, Fist, Fist OP).
-- Os clientes não leem esta tabela: pedem-na à edge function
-- `respostas-sugestoes`, que identifica o terminal por `licencas`.
create table if not exists public.sugestoes_respostas (
  id uuid primary key default gen_random_uuid(),
  sugestao_id uuid not null references public.sugestoes(id) on delete cascade,
  texto text not null,
  criado_em timestamptz not null default now(),
  lida_pelo_cliente boolean not null default false
);
create index if not exists sugestoes_respostas_sugestao_idx
  on public.sugestoes_respostas (sugestao_id);

alter table public.sugestoes_respostas enable row level security;
revoke all on public.sugestoes_respostas from anon, authenticated;
grant select, insert, update, delete on public.sugestoes_respostas to authenticated;

drop policy if exists sugestoes_respostas_admin on public.sugestoes_respostas;
create policy sugestoes_respostas_admin on public.sugestoes_respostas
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
