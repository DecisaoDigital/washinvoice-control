-- ============================================================================
-- Acessos ao WashInvoice Control — PARTE A: controlo de acesso.
--
-- COMO APLICAR
--   SQL Editor do projeto oefqbkhioncakojipqyx. Idempotente.
--   Depende de `public.is_admin()`, que já existe em produção.
--
-- PORQUE EXISTE ESTE FICHEIRO
--   `acessos_organizacoes.sql` (o original) misturava duas coisas muito
--   diferentes e não pode ser aplicado como está — ver o aviso no topo desse
--   ficheiro. Esta Parte A é a fatia **aditiva**: cria tabelas novas, um
--   trigger novo e funções novas. Não toca em `clientes`, `licencas`, `pings`,
--   `aceites_termos` nem `pedidos_renovacao`, nem nas policies delas. Risco
--   zero para o POS.
--
-- O QUE FICA DE FORA (Parte B, adiada)
--   `organizacao_id` nas 5 tabelas de negócio, os triggers que o preenchem e a
--   substituição das policies dessas tabelas. Adiada por decisão de 2026-07-26:
--   enquanto o admin global for o único humano autenticado, `is_admin()` já dá
--   acesso a tudo e as policies actuais (`auth.role() = 'authenticated'`) não
--   expõem nada a ninguém.
--
--   ⚠️ GATILHO PARA REABRIR A PARTE B: a primeira aprovação de uma conta
--   **não-admin** em `pedidos_acesso`. A partir desse momento existe um humano
--   `authenticated` que não é admin, e as policies actuais dão-lhe leitura e
--   escrita totais sobre `clientes`, `pings`, `aceites_termos` e
--   `pedidos_renovacao`. `licencas` está a salvo (só service_role e
--   `is_admin()`). Ver `decidir_pedido_acesso()` mais abaixo — o aviso está
--   repetido no ponto de uso.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Tabelas
-- ---------------------------------------------------------------------------
create table if not exists public.organizacoes (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  nome_normalizado text generated always as (lower(trim(nome))) stored,
  limite_utilizadores integer not null default 1 check (limite_utilizadores > 0),
  criada_em timestamptz not null default now(),
  unique (nome_normalizado)
);

create table if not exists public.convites_organizacao (
  id uuid primary key default gen_random_uuid(),
  organizacao_id uuid not null references public.organizacoes(id) on delete cascade,
  codigo text not null unique,
  email text,
  cargo text not null default 'funcionario' check (cargo in ('admin', 'funcionario')),
  usado_por uuid references auth.users(id),
  criado_em timestamptz not null default now(),
  expira_em timestamptz,
  revogado_em timestamptz
);

create table if not exists public.pedidos_acesso (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  nome text,
  email text not null,
  organizacao_indicada text not null,
  organizacao_id uuid references public.organizacoes(id),
  cargo text not null check (cargo in ('admin', 'funcionario')),
  origem text not null check (origem in ('livre', 'convite')),
  convite_id uuid references public.convites_organizacao(id),
  estado text not null default 'pendente'
    check (estado in ('pendente', 'aprovado', 'recusado', 'revogado')),
  criado_em timestamptz not null default now(),
  decidido_em timestamptz,
  decidido_por uuid references auth.users(id)
);

create index if not exists pedidos_acesso_estado_idx on public.pedidos_acesso(estado, criado_em);
create index if not exists pedidos_acesso_organizacao_idx on public.pedidos_acesso(organizacao_id);

alter table public.organizacoes enable row level security;
alter table public.convites_organizacao enable row level security;
alter table public.pedidos_acesso enable row level security;

-- ---------------------------------------------------------------------------
-- 2. Policies das tabelas novas
-- ---------------------------------------------------------------------------
-- Sem policy de INSERT/DELETE de propósito: inserir é só pelo trigger e pela
-- RPC de convites, ambos `security definer`. Revogar é mudança de estado.
drop policy if exists pedidos_acesso_ler_proprio on public.pedidos_acesso;
drop policy if exists pedidos_acesso_admin_alterar on public.pedidos_acesso;
drop policy if exists organizacoes_admin_ler on public.organizacoes;
drop policy if exists convites_admin_ler on public.convites_organizacao;

create policy pedidos_acesso_ler_proprio on public.pedidos_acesso
  for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy pedidos_acesso_admin_alterar on public.pedidos_acesso
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy organizacoes_admin_ler on public.organizacoes
  for select to authenticated using (public.is_admin());
create policy convites_admin_ler on public.convites_organizacao
  for select to authenticated using (public.is_admin());

-- ---------------------------------------------------------------------------
-- 3. Registo: pedido criado a partir de auth.users
-- ---------------------------------------------------------------------------
-- Corre no insert de `auth.users`, e não numa chamada da app, porque com
-- confirmação de email o utilizador pode só voltar dias depois.
--
-- FILTRO POR APP (correcção face ao ficheiro original): o projeto Supabase é
-- partilhado pelo Control, pelo POS e pelo Fist, e já existe um trigger
-- `punho_criar_pedido_ao_registar` em `auth.users`. Sem filtro, cada registo
-- no Fist criava também um pedido de acesso ao Control e enchia o separador
-- "Acessos" com gente que nunca vai usar o Control.
--
-- O registo do Control não envia `app` nos metadados; qualquer app cliente
-- envia (`punho`, `pos`, ...). Aceita-se `control` explícito para o dia em que
-- o Control passar a enviá-lo.
create or replace function public.criar_pedido_acesso_novo_utilizador()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_app text := lower(trim(coalesce(new.raw_user_meta_data->>'app', '')));
  v_codigo text := nullif(trim(coalesce(new.raw_user_meta_data->>'codigo_convite', '')), '');
  v_convite public.convites_organizacao%rowtype;
  v_nome_org text := trim(coalesce(new.raw_user_meta_data->>'organizacao', ''));
  v_cargo text := lower(coalesce(new.raw_user_meta_data->>'cargo', 'funcionario'));
begin
  if v_app not in ('', 'control') then return new; end if;

  if v_nome_org = '' then v_nome_org := 'Organização por confirmar'; end if;
  if v_cargo not in ('admin', 'funcionario') then v_cargo := 'funcionario'; end if;

  if v_codigo is not null then
    select * into v_convite from public.convites_organizacao
      where codigo = v_codigo and usado_por is null and revogado_em is null
        and (expira_em is null or expira_em > now())
        and (email is null or lower(email) = lower(new.email));
    if found then
      update public.convites_organizacao set usado_por = new.id where id = v_convite.id;
      insert into public.pedidos_acesso
        (user_id, nome, email, organizacao_indicada, organizacao_id, cargo, origem, convite_id)
      select new.id, new.raw_user_meta_data->>'nome', new.email, o.nome, v_convite.organizacao_id,
             v_convite.cargo, 'convite', v_convite.id
        from public.organizacoes o where o.id = v_convite.organizacao_id;
      return new;
    end if;
  end if;

  insert into public.pedidos_acesso
    (user_id, nome, email, organizacao_indicada, cargo, origem)
  values (new.id, new.raw_user_meta_data->>'nome', new.email, v_nome_org, v_cargo, 'livre');
  return new;
end;
$$;

drop trigger if exists ao_criar_utilizador_pedir_acesso on auth.users;
create trigger ao_criar_utilizador_pedir_acesso
  after insert on auth.users
  for each row execute function public.criar_pedido_acesso_novo_utilizador();

-- ---------------------------------------------------------------------------
-- 4. Estado de acesso (consumido pelo arranque da app)
-- ---------------------------------------------------------------------------
-- Ter sessão não basta: sem esta função o Control não abre a ninguém.
create or replace function public.meu_estado_acesso()
returns text language sql stable security definer set search_path = public as $$
  select case
    when public.is_admin() then 'aprovado'
    else coalesce((select estado from public.pedidos_acesso where user_id = auth.uid()), 'pendente')
  end;
$$;
revoke execute on function public.meu_estado_acesso() from public;
grant execute on function public.meu_estado_acesso() to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Decisão do admin global
-- ---------------------------------------------------------------------------
-- ⚠️ APROVAR UMA CONTA NÃO-ADMIN É O GATILHO DA PARTE B.
--    A pessoa aprovada passa a ser `authenticated` neste projeto Supabase e,
--    com as policies actuais, ganha leitura e escrita totais sobre `clientes`,
--    `pings`, `aceites_termos` e `pedidos_renovacao` — o isolamento por
--    organização é precisamente o que ficou adiado. Antes da primeira
--    aprovação de alguém que não seja admin, aplicar a Parte B.
create or replace function public.decidir_pedido_acesso(
  p_pedido_id uuid, p_decisao text, p_organizacao_id uuid default null
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_pedido public.pedidos_acesso%rowtype;
  v_org uuid;
  v_activos integer;
  v_limite integer;
begin
  if not public.is_admin() then raise exception 'Sem permissão'; end if;
  if p_decisao not in ('aprovado', 'recusado', 'revogado') then raise exception 'Decisão inválida'; end if;
  select * into v_pedido from public.pedidos_acesso where id = p_pedido_id for update;
  if not found then raise exception 'Pedido não encontrado'; end if;

  if p_decisao = 'aprovado' then
    v_org := coalesce(p_organizacao_id, v_pedido.organizacao_id);
    if v_org is null then
      insert into public.organizacoes(nome) values (v_pedido.organizacao_indicada) returning id into v_org;
    end if;
    select limite_utilizadores into v_limite from public.organizacoes where id = v_org;
    select count(*) into v_activos from public.pedidos_acesso
      where organizacao_id = v_org and estado = 'aprovado' and id <> v_pedido.id;
    if v_activos >= v_limite then raise exception 'Limite de utilizadores da organização atingido'; end if;
    update public.pedidos_acesso set estado = 'aprovado', organizacao_id = v_org,
      decidido_em = now(), decidido_por = auth.uid() where id = p_pedido_id;
  else
    update public.pedidos_acesso set estado = p_decisao, decidido_em = now(),
      decidido_por = auth.uid() where id = p_pedido_id;
  end if;
end;
$$;
revoke execute on function public.decidir_pedido_acesso(uuid, text, uuid) from public;
grant execute on function public.decidir_pedido_acesso(uuid, text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Convites de gerente
-- ---------------------------------------------------------------------------
-- `minha_organizacao_id()` e `eh_gerente_organizacao()` vinham na secção da
-- Parte B do ficheiro original, mas são precisas aqui: a RPC de convites
-- depende das duas. `tem_acesso_organizacao()` fica de fora — essa só serve as
-- policies das tabelas de negócio.
create or replace function public.minha_organizacao_id()
returns uuid language sql stable security definer set search_path = public as $$
  select organizacao_id from public.pedidos_acesso
   where user_id = auth.uid() and estado = 'aprovado';
$$;

create or replace function public.eh_gerente_organizacao()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.pedidos_acesso
    where user_id = auth.uid() and estado = 'aprovado' and cargo = 'admin');
$$;

revoke execute on function public.minha_organizacao_id() from public;
revoke execute on function public.eh_gerente_organizacao() from public;
grant execute on function public.minha_organizacao_id() to authenticated;
grant execute on function public.eh_gerente_organizacao() to authenticated;

create or replace function public.criar_convite_organizacao(
  p_email text, p_cargo text default 'funcionario'
) returns table(codigo text, expira_em timestamptz)
language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_codigo text; v_expira timestamptz := now() + interval '14 days';
begin
  if not public.eh_gerente_organizacao() then raise exception 'Só um gerente aprovado pode convidar'; end if;
  if p_cargo not in ('admin', 'funcionario') then raise exception 'Cargo inválido'; end if;
  if nullif(trim(p_email), '') is null then raise exception 'Email obrigatório'; end if;
  v_org := public.minha_organizacao_id();
  v_codigo := replace(gen_random_uuid()::text, '-', '');
  insert into public.convites_organizacao(organizacao_id, codigo, email, cargo, expira_em)
    values (v_org, v_codigo, lower(trim(p_email)), p_cargo, v_expira);
  return query select v_codigo, v_expira;
end;
$$;
revoke execute on function public.criar_convite_organizacao(text, text) from public;
grant execute on function public.criar_convite_organizacao(text, text) to authenticated;

commit;
