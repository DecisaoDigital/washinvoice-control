-- Punho — campainha de tempo real sobre `punho_operacoes`
-- Correr uma vez no SQL Editor do Supabase.
--
-- Desenho e alternativas ponderadas: `docs/design/tempo_real.md` (repo Punho).
--
-- ## O que faz
--
-- Quando entra uma operação nova, avisa os aparelhos daquela empresa. Eles, ao
-- ouvirem, fazem o que já sabiam fazer: puxar desde o cursor.
--
-- ## O que NÃO faz, e é o mais importante
--
-- **Não manda os dados.** Vai só o `seq`. A campainha diz *que* há novidades,
-- nunca *quais*.
--
-- A razão é que um WebSocket não é de confiança para entrega: cai, reconecta, e
-- o que passou durante a queda perdeu-se. Quem trata o canal como camião fica
-- com buracos silenciosos nos dados — falta uma reserva e ninguém dá por isso.
-- Quem o trata como campainha só perde uma campainha, e a chegada seguinte (ou
-- o temporizador de segurança da app) repõe tudo.
--
-- Efeito prático: o tempo real é uma optimização de latência, não um caminho de
-- dados. Se isto falhar por completo, a app continua correcta — só volta a ser
-- tão lenta como era antes.
--
-- Também não passa por aqui o RLS dos dados: quem ouve vai buscar as operações
-- pelo caminho normal, onde as políticas de `punho_operacoes` se aplicam.

-- ---------------------------------------------------------------------------
-- Quem pode ouvir
-- ---------------------------------------------------------------------------

-- Canal privado, um por empresa. Sem esta política ninguém ouve nada: sem
-- política nenhuma, `realtime.messages` está fechado a `authenticated`.
drop policy if exists punho_ouvir_canal_da_empresa on realtime.messages;
create policy punho_ouvir_canal_da_empresa
  on realtime.messages
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.punho_membros m
      where m.user_id = auth.uid()
        and m.ativo
        and realtime.topic() = 'punho:empresa:' || m.empresa_id::text
    )
  );

-- ---------------------------------------------------------------------------
-- A partição do dia
-- ---------------------------------------------------------------------------
--
-- `realtime.messages` é **particionada por dia** e este projecto não tinha uma
-- única partição — nem `pg_cron` para as criar. Sem partição, o `INSERT` falha
-- com "no partition of relation found for row"… e a `realtime.send` **engole o
-- erro** com um simples WARNING (está no código dela).
--
-- Resultado: a campainha nunca tocaria, nada apareceria nos registos, e a
-- funcionalidade parecia estar lá. Foi assim que este defeito quase passou.
--
-- Como não há cron, cria-se a partição à medida que é precisa. A verificação é
-- um `to_regclass`, uma consulta ao catálogo — barata ao ponto de não se notar
-- por operação gravada.
create or replace function public.punho_garantir_particao_realtime(p_dia date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome text := format('messages_%s', to_char(p_dia, 'YYYY_MM_DD'));
begin
  if to_regclass('realtime.' || quote_ident(v_nome)) is not null then
    return;
  end if;
  execute format(
    'create table realtime.%I partition of realtime.messages '
    'for values from (%L) to (%L)',
    v_nome, p_dia, p_dia + 1
  );
exception when others then
  -- Duas transacções a criar a mesma partição ao mesmo tempo, ou falta de
  -- permissões. Nunca pode abortar a operação que está a ser gravada.
  raise warning 'particao realtime %: %', v_nome, sqlerrm;
end;
$$;

comment on function public.punho_garantir_particao_realtime(date) is
  'Cria a particao diaria de realtime.messages se faltar. Existe porque o '
  'projecto nao tem pg_cron e a realtime.send falha em silencio sem particao.';

-- ---------------------------------------------------------------------------
-- A campainha
-- ---------------------------------------------------------------------------

create or replace function public.punho_operacoes_avisar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- O `begin/exception` não é zelo a mais: este trigger corre DENTRO da
  -- transacção do INSERT. Sem ele, uma falha do Realtime — indisponível,
  -- schema em migração, o que for — abortava a gravação da operação.
  --
  -- A campainha nunca pode partir a porta. Se não tocar, o pior que acontece é
  -- o outro aparelho só ver a novidade daqui a cinco minutos, que é
  -- exactamente como as coisas eram antes de isto existir.
  begin
    -- Hoje e amanhã: uma operação gravada mesmo em cima da meia-noite UTC pode
    -- cair na partição do dia seguinte.
    perform public.punho_garantir_particao_realtime(current_date);
    perform public.punho_garantir_particao_realtime(current_date + 1);

    perform realtime.send(
      jsonb_build_object('seq', NEW.seq),          -- só a campainha
      'nova_operacao',                             -- evento
      'punho:empresa:' || NEW.empresa_id::text,    -- um canal por empresa
      true                                         -- privado (usa a política acima)
    );
  exception when others then
    raise warning 'campainha do Punho falhou (seq %): %', NEW.seq, sqlerrm;
  end;

  return null;  -- AFTER trigger: o valor devolvido é ignorado
end;
$$;

comment on function public.punho_operacoes_avisar() is
  'Avisa os aparelhos da empresa de que ha operacoes novas. Envia SO o seq — '
  'quem ouve puxa pelo caminho normal. Falha em silencio de proposito: nao '
  'pode abortar a insercao da operacao.';

drop trigger if exists punho_operacoes_avisar_trigger on public.punho_operacoes;
create trigger punho_operacoes_avisar_trigger
  after insert on public.punho_operacoes
  for each row
  execute function public.punho_operacoes_avisar();
