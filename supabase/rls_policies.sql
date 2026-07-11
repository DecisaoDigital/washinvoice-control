-- ============================================================
-- WashInvoice Control — Row Level Security (RLS)
-- ------------------------------------------------------------
-- Cola este script no SQL Editor do Supabase e carrega em "Run".
-- É IDEMPOTENTE: pode ser corrido as vezes que forem precisas.
-- Começa por apagar TODAS as policies existentes nas 5 tabelas de
-- dados (limpa qualquer policy permissiva deixada em dev) e recria
-- o conjunto limpo abaixo.
--
-- MODELO (Opção D) — três principais:
--   * anon (a chave pública no binário)  -> NADA em tabelas de dados.
--       O único caminho aberto ao anon é o RPC registar_ping_inicial(),
--       para máquinas novas que ainda não têm licença/credenciais.
--   * POS autenticado (authenticated, NÃO admin) -> lê só a SUA licença
--       (user_id = auth.uid()) e insere pings/aceites/pedidos da sua
--       própria máquina.
--   * Admin Control (authenticated E presente na tabela admins) ->
--       acesso total às 5 tabelas (sem DELETE).
--
-- DELETE: bloqueado em todas as tabelas (nenhum fluxo o usa hoje).
--
-- PASSO MANUAL OBRIGATÓRIO no fim: registar o utilizador admin na
-- tabela `admins` (secção 6). Sem isso, NINGUÉM é admin e o Control
-- autenticado fica sem acesso.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 1. Alterações de schema
-- ------------------------------------------------------------

-- 1a. Liga cada licença ao utilizador (POS) que a ela pertence.
--     Nullable por agora: licenças antigas/demo ficam órfãs (user_id null)
--     até serem reemitidas. Passar a NOT NULL só quando todas migrarem.
alter table public.licencas
  add column if not exists user_id uuid references auth.users(id);

create index if not exists licencas_user_id_idx
  on public.licencas (user_id) where user_id is not null;

-- 1b. Quem é admin do Control. Geri-se manualmente (Dashboard/SQL);
--     não é escrita pela app. RLS ligado e SEM policy => ninguém lê via
--     API; só a função is_admin() (SECURITY DEFINER) lhe acede.
create table if not exists public.admins (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  criado_em timestamptz not null default now()
);

alter table public.admins enable row level security;

-- ------------------------------------------------------------
-- 2. Função auxiliar is_admin()
-- ------------------------------------------------------------
-- SECURITY DEFINER: corre com os privilégios do dono (postgres), pelo
-- que consegue ler `admins` sem precisar de policy nem de expor a tabela
-- ao role authenticated, e evita recursão de RLS.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admins a where a.user_id = auth.uid()
  );
$$;

revoke execute on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- ------------------------------------------------------------
-- 3. RPC de ping inicial (máquinas pré-licença)
-- ------------------------------------------------------------
-- Máquinas novas comunicam ANTES de terem licença/credenciais (fluxo
-- "Início de atividade" no Dashboard). Como o anon não escreve em `pings`,
-- este RPC SECURITY DEFINER faz o INSERT contornando a policy — é o ÚNICO
-- caminho de escrita aberto ao anon.
create or replace function public.registar_ping_inicial(
  p_machine_id text,
  p_nif        text,
  p_versao     text,
  p_lat        double precision,
  p_lon        double precision,
  p_cidade     text,
  p_metodo_geo text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.pings
    (machine_id, nif, versao, lat, lon, cidade, metodo_geo)
  values
    (p_machine_id, p_nif, p_versao, p_lat, p_lon, p_cidade, p_metodo_geo);
end;
$$;

revoke execute on function public.registar_ping_inicial(
  text, text, text, double precision, double precision, text, text
) from public;
grant execute on function public.registar_ping_inicial(
  text, text, text, double precision, double precision, text, text
) to anon;
-- TODO (ronda seguinte): rate-limit por IP (ex.: pg_net/edge) para evitar
-- flood de pings via anon. Fica documentado; não bloqueia esta ronda.

-- ------------------------------------------------------------
-- 4. Limpeza: apagar TODAS as policies existentes nas tabelas de dados
-- ------------------------------------------------------------
-- Garante clean slate — nenhuma policy permissiva de dev sobrevive.
do $$
declare
  r record;
begin
  for r in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
      and tablename in
        ('clientes','licencas','pings','pedidos_renovacao','aceites_termos')
  loop
    execute format('drop policy if exists %I on public.%I',
                   r.policyname, r.tablename);
  end loop;
end $$;

-- ------------------------------------------------------------
-- 5. RLS + policies por tabela
-- ------------------------------------------------------------

-- ---------- licencas ----------
alter table public.licencas enable row level security;

-- SELECT: admin vê tudo; POS vê só a sua licença.
create policy licencas_select on public.licencas
  for select to authenticated
  using ( public.is_admin() or user_id = auth.uid() );

-- INSERT/UPDATE: só admin (o POS nunca escreve em licencas).
create policy licencas_insert on public.licencas
  for insert to authenticated
  with check ( public.is_admin() );

create policy licencas_update on public.licencas
  for update to authenticated
  using ( public.is_admin() )
  with check ( public.is_admin() );

-- Sem policy DELETE => DELETE bloqueado. Sem policy para anon => anon nada.

-- ---------- clientes ----------
alter table public.clientes enable row level security;

-- Só admin (o POS não toca em clientes).
create policy clientes_select on public.clientes
  for select to authenticated
  using ( public.is_admin() );

create policy clientes_insert on public.clientes
  for insert to authenticated
  with check ( public.is_admin() );

create policy clientes_update on public.clientes
  for update to authenticated
  using ( public.is_admin() )
  with check ( public.is_admin() );

-- ---------- pings ----------
alter table public.pings enable row level security;

-- SELECT: só admin (o POS não lê pings).
create policy pings_select on public.pings
  for select to authenticated
  using ( public.is_admin() );

-- INSERT: admin, ou POS a inserir ping da SUA máquina (existe uma licença
-- do próprio auth.uid() com esse machine_id). Máquinas pré-licença usam o
-- RPC registar_ping_inicial(), não esta policy.
create policy pings_insert on public.pings
  for insert to authenticated
  with check (
    public.is_admin()
    or exists (
      select 1 from public.licencas l
      where l.user_id = auth.uid()
        and l.machine_id = pings.machine_id
    )
  );

-- ---------- aceites_termos ----------
alter table public.aceites_termos enable row level security;

-- SELECT: só admin.
create policy aceites_select on public.aceites_termos
  for select to authenticated
  using ( public.is_admin() );

-- INSERT: admin, ou POS a registar aceite da SUA máquina.
create policy aceites_insert on public.aceites_termos
  for insert to authenticated
  with check (
    public.is_admin()
    or exists (
      select 1 from public.licencas l
      where l.user_id = auth.uid()
        and l.machine_id = aceites_termos.machine_id
    )
  );

-- ---------- pedidos_renovacao ----------
alter table public.pedidos_renovacao enable row level security;

-- SELECT: só admin (o Control lista os pendentes).
create policy pedidos_select on public.pedidos_renovacao
  for select to authenticated
  using ( public.is_admin() );

-- INSERT: admin, ou POS a pedir renovação da SUA máquina.
create policy pedidos_insert on public.pedidos_renovacao
  for insert to authenticated
  with check (
    public.is_admin()
    or exists (
      select 1 from public.licencas l
      where l.user_id = auth.uid()
        and l.machine_id = pedidos_renovacao.machine_id
    )
  );

-- UPDATE (confirmar): só admin.
create policy pedidos_update on public.pedidos_renovacao
  for update to authenticated
  using ( public.is_admin() )
  with check ( public.is_admin() );

-- ------------------------------------------------------------
-- 6. PASSO MANUAL — registar o utilizador admin (Cesar)
-- ------------------------------------------------------------
-- 1) Cria o utilizador em Authentication -> Users (email+password).
-- 2) Copia o UUID do utilizador e descomenta a linha abaixo com esse UUID.
-- SEM isto, is_admin() devolve false para todos e o Control autenticado
-- fica sem acesso a nenhuma tabela.
--
-- insert into public.admins (user_id)
-- values ('00000000-0000-0000-0000-000000000000')
-- on conflict (user_id) do nothing;

commit;
