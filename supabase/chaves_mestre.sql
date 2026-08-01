-- WashInvoice / Punho — chave mestre da empresa
-- Correr uma vez no SQL Editor do Supabase.
--
-- Desenho: docs/design/chaves_empresa_e_dispositivo.md (repo do Punho).
--
-- O par que identifica um posto de trabalho é `chave mestre + chave de
-- dispositivo`. A chave de dispositivo já existe e já funciona nas duas apps
-- (`licencas.machine_id`, SHA-256 calculado pela própria máquina). A chave
-- mestre não existia em lado nenhum — é o que esta migração cria.
--
-- Regras que o desenho fixou e que aqui se traduzem:
--   • uma por empresa, ligada ao NIF (não ao aparelho, não à app)
--   • nasce na PRIMEIRA associação de um dispositivo — mas o valor é novo e
--     opaco, sem nada dentro que venha daquela máquina. Tem de sobreviver à
--     substituição de todos os aparelhos, incluindo o primeiro.
--   • o prefixo legível é decoração, para ser lido ao telefone

create table if not exists public.chaves_mestre (
  nif                    text primary key,
  chave                  text not null unique,
  nome                   text,
  criada_em              timestamptz not null default now(),
  criada_por_machine_id  text,
  criada_por_app         text,
  notas                  text
);

comment on table public.chaves_mestre is
  'Chave mestre da empresa (uma por NIF), metade do par mestre+dispositivo. '
  'Nasce na primeira associação de um dispositivo; o valor é opaco e não '
  'deriva dessa máquina. Escrita por service_role (Edge Functions); lida por '
  'authenticated com is_admin() no Control.';

comment on column public.chaves_mestre.criada_por_machine_id is
  'Só rasto: que aparelho estava presente quando a chave nasceu. A chave NÃO '
  'deriva dele e sobrevive-lhe.';

-- ---------------------------------------------------------------------------
-- Geração do valor
-- ---------------------------------------------------------------------------

-- Alfabeto sem caracteres que se confundem ao telefone ou à vista:
-- sem 0/O, sem 1/I/L. 32 símbolos → 12 posições ≈ 60 bits de entropia.
create or replace function public.gerar_chave_mestre(p_prefixo text default null)
returns text
language plpgsql
as $$
declare
  alfabeto constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  corpo    text := '';
  pref     text;
  i        int;
begin
  -- Prefixo: só letras, maiúsculas, no máximo 6. Vazio → sem prefixo.
  pref := upper(regexp_replace(coalesce(p_prefixo, ''), '[^A-Za-z]', '', 'g'));
  pref := left(pref, 6);

  for i in 1..12 loop
    corpo := corpo || substr(alfabeto, 1 + floor(random() * length(alfabeto))::int, 1);
  end loop;

  return case when pref = '' then corpo else pref || '-' || corpo end;
end;
$$;

-- ---------------------------------------------------------------------------
-- Obter ou criar — idempotente, é o único caminho para criar uma chave mestre
-- ---------------------------------------------------------------------------

-- Chamada na primeira associação de um dispositivo. Se a empresa já tem chave,
-- devolve a que existe (nunca gera uma segunda: é o que garante que o segundo
-- terminal do mesmo NIF entra na MESMA empresa em vez de fundar outra).
create or replace function public.obter_ou_criar_chave_mestre(
  p_nif        text,
  p_machine_id text default null,
  p_app        text default null,
  p_nome       text default null,
  p_prefixo    text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_chave text;
  v_nova  text;
  tentativa int := 0;
begin
  if p_nif is null or btrim(p_nif) = '' then
    raise exception 'NIF em falta: a chave mestre é sempre de uma empresa';
  end if;

  select chave into v_chave from public.chaves_mestre where nif = btrim(p_nif);
  if v_chave is not null then
    return v_chave;
  end if;

  -- Colisão é improvável, mas não se deixa ao acaso: tenta até 5 vezes.
  loop
    tentativa := tentativa + 1;
    v_nova := public.gerar_chave_mestre(p_prefixo);

    begin
      insert into public.chaves_mestre
        (nif, chave, nome, criada_por_machine_id, criada_por_app)
      values
        (btrim(p_nif), v_nova, p_nome, p_machine_id, p_app);
      return v_nova;
    exception
      when unique_violation then
        -- Ou a chave colidiu, ou outra sessão criou a da empresa entretanto.
        select chave into v_chave from public.chaves_mestre where nif = btrim(p_nif);
        if v_chave is not null then
          return v_chave;
        end if;
        if tentativa >= 5 then
          raise;
        end if;
    end;
  end loop;
end;
$$;

-- Só as Edge Functions criam chaves mestre. Um cliente com anon/authenticated
-- que pudesse chamar isto fundava empresas à vontade.
revoke all on function public.obter_ou_criar_chave_mestre(text, text, text, text, text) from public, anon, authenticated;
revoke all on function public.gerar_chave_mestre(text) from public, anon, authenticated;
grant execute on function public.obter_ou_criar_chave_mestre(text, text, text, text, text) to service_role;
grant execute on function public.gerar_chave_mestre(text) to service_role;

-- ---------------------------------------------------------------------------
-- RLS — mesmo padrão de `licencas`: service_role escreve, admin lê, anon fora
-- ---------------------------------------------------------------------------

alter table public.chaves_mestre enable row level security;

drop policy if exists chaves_mestre_admin_select on public.chaves_mestre;
create policy chaves_mestre_admin_select
  on public.chaves_mestre for select
  to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- A licença passa a levar a chave mestre
-- ---------------------------------------------------------------------------

-- Retrocompatível: as licenças já emitidas ficam com NULL e continuam válidas
-- (a base assinada só inclui a chave mestre quando ela existe — ver
-- lib/services/licenca_assinatura.dart).
alter table public.licencas add column if not exists chave_mestre text;

comment on column public.licencas.chave_mestre is
  'Metade "empresa" do par. NULL nas licenças anteriores a esta mudança — '
  'essas continuam a validar pela base assinada antiga.';

create index if not exists licencas_chave_mestre_idx
  on public.licencas (chave_mestre) where chave_mestre is not null;
