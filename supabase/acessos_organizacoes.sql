-- ############################################################################
-- ⛔ NÃO APLICAR ESTE FICHEIRO. Foi dividido em 2026-07-26.
--
--    Aplicar:  acessos_organizacoes_parte_a.sql   (controlo de acesso)
--    Adiada:   a segunda metade deste ficheiro     (organizacao_id nas 5
--              tabelas de negócio + substituição das policies delas)
--
-- PORQUÊ: este ficheiro assume o modelo do rls_policies.sql — POS autenticado
-- com `licencas.user_id`. Produção nunca adoptou esse modelo: `licencas.user_id`
-- NÃO EXISTE, e a frota POS escreve pings/aceites/renovações por policies de
-- role `public` com check `true`. Aplicado como está, este script:
--   1) dropa TODAS as policies das 5 tabelas de negócio (incluindo as que
--      servem a frota), e só depois
--   2) falha ao criar policies que referem `licencas.user_id`.
-- Verificado contra produção em 2026-07-26 antes de qualquer escrita.
--
-- A segunda metade só volta à mesa quando for aprovada a primeira conta
-- não-admin em `pedidos_acesso` — ver o cabeçalho da Parte A.
-- ############################################################################

-- Gestão de organizações e acessos. Executar SEMPRE depois de rls_policies.sql
-- (depende de public.admins e de public.is_admin()).
-- É IDEMPOTENTE: pode ser corrido as vezes que forem precisas.
-- Todas as aprovações são manuais no WashInvoice Control.
--
-- Não toca em auth.users a não ser para instalar o trigger de criação do
-- pedido, e não apaga dados. Linhas existentes ficam com organizacao_id null:
-- só o admin global as vê, até serem migradas à mão.
--
-- Aumentar o limite de utilizadores de uma organização é um passo manual
-- (SQL/Dashboard): update public.organizacoes set limite_utilizadores = N ...
-- `organizacoes` não tem policy de UPDATE de propósito; a app nunca lhe escreve.
-- Ideia por decidir (NÃO implementar sem indicação): expor isto ao admin global
-- no separador Acessos via RPC definir_limite_organizacao() SECURITY DEFINER.
-- Ver "Próxima ronda" no ROADMAP.md da raiz.

begin;

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

-- Cria o pedido logo que o utilizador se regista. Funciona mesmo quando a
-- confirmação de email está activa e ainda não existe sessão no telemóvel.
create or replace function public.criar_pedido_acesso_novo_utilizador()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_codigo text := nullif(trim(coalesce(new.raw_user_meta_data->>'codigo_convite', '')), '');
  v_convite public.convites_organizacao%rowtype;
  v_nome_org text := trim(coalesce(new.raw_user_meta_data->>'organizacao', ''));
  v_cargo text := lower(coalesce(new.raw_user_meta_data->>'cargo', 'funcionario'));
begin
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

-- A app só consulta o próprio pedido; o Control vê todos por ser admin global.
-- Drops explícitos para o script poder correr as vezes que forem precisas.
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

-- Estado usado no arranque: uma sessão autenticada não é suficiente para
-- entrar; é obrigatória uma aprovação manual.
create or replace function public.meu_estado_acesso()
returns text language sql stable security definer set search_path = public as $$
  select case
    when public.is_admin() then 'aprovado'
    else coalesce((select estado from public.pedidos_acesso where user_id = auth.uid()), 'pendente')
  end;
$$;
revoke execute on function public.meu_estado_acesso() from public;
grant execute on function public.meu_estado_acesso() to authenticated;

-- Aprovação/recusa/revogação exclusivamente no Control. Para pedidos livres,
-- p_organizacao_id permite escolher uma empresa existente; nulo cria uma nova.
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

-- -------------------------------------------------------------------------
-- Isolamento dos dados de negócio por organização
-- -------------------------------------------------------------------------
-- O admin global (WashInvoice Control) continua a ver tudo. Um utilizador
-- aprovado vê/escreve exclusivamente linhas da sua organização.
alter table public.clientes add column if not exists organizacao_id uuid
  references public.organizacoes(id);
alter table public.licencas add column if not exists organizacao_id uuid
  references public.organizacoes(id);
alter table public.pings add column if not exists organizacao_id uuid
  references public.organizacoes(id);
alter table public.aceites_termos add column if not exists organizacao_id uuid
  references public.organizacoes(id);
alter table public.pedidos_renovacao add column if not exists organizacao_id uuid
  references public.organizacoes(id);

create index if not exists clientes_organizacao_idx on public.clientes(organizacao_id);
create index if not exists licencas_organizacao_idx on public.licencas(organizacao_id);
create index if not exists pings_organizacao_idx on public.pings(organizacao_id);

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

-- Tem de devolver sempre true/false: usada em policies, onde NULL bloqueia de
-- forma silenciosa. Linhas antigas (organizacao_id null) só são visíveis para o
-- admin global — nunca por suposição de organização.
create or replace function public.tem_acesso_organizacao(p_organizacao_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.is_admin(), false)
      or (p_organizacao_id is not null
          and p_organizacao_id = public.minha_organizacao_id());
$$;

revoke execute on function public.minha_organizacao_id() from public;
revoke execute on function public.eh_gerente_organizacao() from public;
revoke execute on function public.tem_acesso_organizacao(uuid) from public;
grant execute on function public.minha_organizacao_id(), public.eh_gerente_organizacao(),
  public.tem_acesso_organizacao(uuid) to authenticated;

-- Preenche automaticamente a organização em inserções feitas por uma conta
-- aprovada. O admin global pode definir a organização explicitamente.
--
-- NÃO levanta excepção quando não há organização: os caminhos legítimos do POS
-- (ping da própria máquina, aceite de termos, pedido de renovação) e o RPC
-- registar_ping_inicial() do anon inserem sem organização. Quem decide se a
-- linha pode ou não entrar é a policy de RLS, não este trigger.
create or replace function public.preencher_organizacao_linha()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.organizacao_id is null then
    new.organizacao_id := public.minha_organizacao_id();
  end if;
  return new;
end;
$$;

drop trigger if exists clientes_preencher_organizacao on public.clientes;
create trigger clientes_preencher_organizacao before insert on public.clientes
  for each row execute function public.preencher_organizacao_linha();
drop trigger if exists licencas_preencher_organizacao on public.licencas;
create trigger licencas_preencher_organizacao before insert on public.licencas
  for each row execute function public.preencher_organizacao_linha();
drop trigger if exists pings_preencher_organizacao on public.pings;
create trigger pings_preencher_organizacao before insert on public.pings
  for each row execute function public.preencher_organizacao_linha();
drop trigger if exists aceites_preencher_organizacao on public.aceites_termos;
create trigger aceites_preencher_organizacao before insert on public.aceites_termos
  for each row execute function public.preencher_organizacao_linha();
drop trigger if exists pedidos_preencher_organizacao on public.pedidos_renovacao;
create trigger pedidos_preencher_organizacao before insert on public.pedidos_renovacao
  for each row execute function public.preencher_organizacao_linha();

-- Substitui as policies antigas por regras de organização.
do $$ declare r record; begin
  for r in select policyname, tablename from pg_policies where schemaname = 'public'
    and tablename in ('clientes','licencas','pings','aceites_termos','pedidos_renovacao') loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- ATENÇÃO: as policies abaixo substituem as de rls_policies.sql e têm de
-- CONSERVAR o acesso do POS autenticado, que não pertence a organização
-- nenhuma (não tem linha em pedidos_acesso). Sem os ramos `user_id`/`licencas
-- da própria máquina`, todo o parque instalado deixaria de ler a sua licença e
-- de registar pings, aceites e pedidos de renovação.

-- ---------- clientes (só admin global / organização) ----------
create policy clientes_organizacao_ler on public.clientes for select to authenticated
  using (public.tem_acesso_organizacao(organizacao_id));
create policy clientes_organizacao_inserir on public.clientes for insert to authenticated
  with check (public.tem_acesso_organizacao(organizacao_id));
create policy clientes_organizacao_atualizar on public.clientes for update to authenticated
  using (public.tem_acesso_organizacao(organizacao_id)) with check (public.tem_acesso_organizacao(organizacao_id));

-- ---------- licencas ----------
-- O POS continua a ler exclusivamente a SUA licença.
create policy licencas_organizacao_ler on public.licencas for select to authenticated
  using (public.tem_acesso_organizacao(organizacao_id) or user_id = auth.uid());
create policy licencas_organizacao_inserir on public.licencas for insert to authenticated
  with check (public.tem_acesso_organizacao(organizacao_id));
create policy licencas_organizacao_atualizar on public.licencas for update to authenticated
  using (public.tem_acesso_organizacao(organizacao_id)) with check (public.tem_acesso_organizacao(organizacao_id));

-- ---------- pings ----------
-- Leitura só do Control/organização; escrita também do POS da própria máquina.
-- Máquinas pré-licença continuam a usar o RPC registar_ping_inicial() (anon).
create policy pings_organizacao_ler on public.pings for select to authenticated
  using (public.tem_acesso_organizacao(organizacao_id));
create policy pings_organizacao_inserir on public.pings for insert to authenticated
  with check (
    public.tem_acesso_organizacao(organizacao_id)
    or exists (select 1 from public.licencas l
                where l.user_id = auth.uid() and l.machine_id = pings.machine_id)
  );

-- ---------- aceites_termos ----------
create policy aceites_organizacao_ler on public.aceites_termos for select to authenticated
  using (public.tem_acesso_organizacao(organizacao_id));
create policy aceites_organizacao_inserir on public.aceites_termos for insert to authenticated
  with check (
    public.tem_acesso_organizacao(organizacao_id)
    or exists (select 1 from public.licencas l
                where l.user_id = auth.uid() and l.machine_id = aceites_termos.machine_id)
  );

-- ---------- pedidos_renovacao ----------
create policy pedidos_organizacao_ler on public.pedidos_renovacao for select to authenticated
  using (public.tem_acesso_organizacao(organizacao_id));
create policy pedidos_organizacao_inserir on public.pedidos_renovacao for insert to authenticated
  with check (
    public.tem_acesso_organizacao(organizacao_id)
    or exists (select 1 from public.licencas l
                where l.user_id = auth.uid() and l.machine_id = pedidos_renovacao.machine_id)
  );
create policy pedidos_organizacao_atualizar on public.pedidos_renovacao for update to authenticated
  using (public.tem_acesso_organizacao(organizacao_id)) with check (public.tem_acesso_organizacao(organizacao_id));

-- Convites: só gerentes aprovados podem criar para a própria organização.
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
