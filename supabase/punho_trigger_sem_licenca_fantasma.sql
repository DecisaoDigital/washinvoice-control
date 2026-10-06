-- Fist — o trigger da empresa deixa de fabricar instalações
-- Correr uma vez no SQL Editor do Supabase.
--
-- ## O que estava mal
--
-- `punho_sync_licenca_from_empresa()` criava, ao guardar os dados da empresa,
-- uma linha em `licencas` com `machine_id = 'punho:' || empresa.id`, plano
-- `beta` e 180 dias de validade.
--
-- Essa linha **não é uma instalação**. Não corresponde a aparelho nenhum, o
-- `machine_id` não é um identificador de máquina (é o id da empresa com um
-- prefixo), e nenhum dispositivo a valida jamais. Mas aparece na lista de
-- instalações do Control exactamente como as verdadeiras — e conta como mais
-- um terminal do cliente.
--
-- Existia por uma razão real: era assim que o Control passava a ver uma empresa
-- Fist, porque a lista dele lê `licencas` e não `punho_empresas`. Resolvia o
-- sintoma inventando dados.
--
-- ## O que passa a fazer
--
-- Deixa de criar seja o que for. Passa só a **manter actualizadas as
-- instalações reais** desta empresa — as que um aparelho registou e que já
-- estão atribuídas a este NIF.
--
-- Consequência assumida: uma empresa cujo aparelho ainda não foi ligado ao NIF
-- não aparece na lista com o seu nome. Aparece a instalação real, com NIF
-- `000000000` e `pendente_revisao = true` — que é a verdade, e é o sinal que o
-- Control já tem para "instalação nova por rever".
--
-- ## Antes de correr
--
-- Se ainda houver linhas fantasma, ligar primeiro os aparelhos reais ao NIF da
-- empresa. Apagar as fantasmas antes disso faz a empresa desaparecer da lista
-- do Control (é a única linha que a nomeia).
--
--   select machine_id, nif, nome from public.licencas
--    where app = 'punho' and machine_id like 'punho:%';

create or replace function public.punho_sync_licenca_from_empresa()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nif            text := NEW.dados->>'nif';
  v_nome_comercial text := NEW.dados->>'nome_comercial';
begin
  if v_nif is null or length(v_nif) < 9 then
    return NEW;
  end if;

  -- NÃO cria linha nenhuma. Uma instalação nasce quando um aparelho se regista
  -- (`registar-terminal`), nunca quando alguém edita os dados da empresa.
  --
  -- `info_host` NÃO se toca de propósito: numa instalação real guarda o
  -- diagnóstico do aparelho (modelo, versão do SO, versão da app). A versão
  -- antiga escrevia lá os dados da empresa por cima, e num terminal real isso
  -- apagava a única informação que diz *que máquina é aquela*.
  update public.licencas
     set nome           = coalesce(v_nome_comercial, NEW.nome),
         nome_comercial = v_nome_comercial
   where app = 'punho'
     and nif = v_nif;

  return NEW;
end;
$$;

comment on function public.punho_sync_licenca_from_empresa() is
  'Mantém o nome das instalações Fist de uma empresa em dia. NÃO cria '
  'licenças: até 1 ago 2026 fabricava uma linha por empresa (machine_id '
  '"punho:<id>") que aparecia no Control como um terminal instalado sem o ser.';

-- ---------------------------------------------------------------------------
-- Limpeza das fantasmas já existentes
-- ---------------------------------------------------------------------------
--
-- Correr SÓ depois de confirmar que cada empresa afectada tem pelo menos uma
-- instalação real atribuída ao seu NIF — senão desaparece da lista do Control.
--
--   delete from public.licencas
--    where app = 'punho'
--      and machine_id like 'punho:%';
