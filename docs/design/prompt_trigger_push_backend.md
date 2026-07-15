# Prompt — Trigger DB automático para push (Task 19)

> Backend Supabase puro (sem Flutter). Pode ser executado por:
> - **Claude via MCP** (Cesar diz "aplica tu"), ou
> - **Claude Code** (colar este prompt numa sessão nova aberta em `D:\WashInvoiceControl\washinvoice_control\`), ou
> - **Cesar manualmente** no SQL Editor do Supabase (copiar/colar os blocos SQL).

---

## Contexto

Estado actual do pipeline FCM:
- Edge Function `enviar-push` deployada e funcional (`verify_jwt: false`, autentica via header `Authorization: Bearer <EDGE_INVOKE_SECRET>`).
- Tabela `admin_dispositivos` guarda tokens FCM do admin autenticado.
- Extensão `pg_net` já activada.
- **Falta**: push automático quando algo relevante acontece na base. Hoje só sai quando alguém chama a Edge Function manualmente (curl).

Objectivo: dois triggers DB que chamam `enviar-push` sozinhos:
1. **Início de actividade** — INSERT em `pings` com `machine_id` sem licença.
2. **Pedido de ajuda** — INSERT em `pedidos_ajuda`.

Sugestões (`sugestoes`) **não** disparam push — não são urgentes; o Cesar consulta quando quer.

---

## Fase 1 — Confirmar estado

Executar as queries abaixo e reportar. **Não avançar sem confirmação.**

```sql
-- pg_net activo?
select exists(select 1 from pg_extension where extname = 'pg_net') as pg_net_activo;

-- supabase_vault activo?
select exists(select 1 from pg_extension where extname = 'supabase_vault') as vault_activo;

-- Tabelas alvo existem?
select
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='pings')          as tem_pings,
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='pedidos_ajuda') as tem_pedidos_ajuda,
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='licencas')      as tem_licencas,
  exists(select 1 from information_schema.tables where table_schema='public' and table_name='clientes')      as tem_clientes;

-- Edge Function existe e está ACTIVE?
-- (verificar via list_edge_functions no MCP ou no dashboard)

-- Já existe algum secret no vault chamado edge_invoke_secret?
select exists(
  select 1 from vault.secrets where name = 'edge_invoke_secret'
) as secret_ja_existe;
```

Se `pg_net_activo = false` → activar antes de continuar (`create extension pg_net`).
Se `vault_activo = false` → activar antes de continuar (`create extension supabase_vault`).
Se `tem_pedidos_ajuda = false` → o prompt de redesign v1.4 ainda não foi aplicado. Parar aqui até estar aplicado.

---

## Fase 2 — Guardar EDGE_INVOKE_SECRET no vault

O trigger não consegue ler os "Edge Function Secrets" do Supabase (esses só existem no runtime das Edge Functions). Precisa de aceder ao secret via `supabase_vault`, que é acessível pelo Postgres.

```sql
-- Criar o secret (não fazer se já existir — vault não sobrescreve).
select vault.create_secret(
  '186e626e50b31e4806bfac3ff8b5d9b30a3aa91cbbdf2a7efe8e989222df5470',
  'edge_invoke_secret',
  'Secret partilhado para triggers chamarem a Edge Function enviar-push'
);

-- Verificar que ficou.
select name, description, created_at
from vault.secrets
where name = 'edge_invoke_secret';
```

O valor `186e626e50b31...` é o mesmo que está nos Edge Function Secrets como `EDGE_INVOKE_SECRET`. **Não expor este valor fora do vault.**

---

## Fase 3 — Trigger de início de actividade

```sql
create or replace function public.notificar_inicio_actividade()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  ja_notificado boolean;
  invoke_secret text;
begin
  -- 1. Só interessa se este machine_id AINDA não tem licença activa.
  --    Se já tem, é ping de rotina — silenciar.
  if exists (
    select 1 from licencas l
    where l.machine_id = new.machine_id
      and coalesce(l.activa, true)
  ) then
    return new;
  end if;

  -- 2. Só o PRIMEIRO ping deste machine_id dispara push. Evita spam quando
  --    um POS sem licença faz ping a cada 6h — só queremos saber uma vez.
  select exists (
    select 1 from pings p
    where p.machine_id = new.machine_id
      and p.id <> new.id
  ) into ja_notificado;
  if ja_notificado then return new; end if;

  -- 3. Buscar secret do vault. Se não existir, falhar silenciosamente
  --    (não queremos que o INSERT do ping bloqueie por causa disto).
  select decrypted_secret into invoke_secret
  from vault.decrypted_secrets
  where name = 'edge_invoke_secret';
  if invoke_secret is null then return new; end if;

  -- 4. Disparar push. pg_net.http_post é assíncrono — não bloqueia o INSERT.
  perform net.http_post(
    url := 'https://oefqbkhioncakojipqyx.supabase.co/functions/v1/enviar-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || invoke_secret
    ),
    body := jsonb_build_object(
      'title', 'Novo terminal a comunicar',
      'body', coalesce(
        'NIF ' || new.nif,
        'Máquina ' || left(new.machine_id, 8) || '…'
      ) || case when new.cidade is not null then ' — ' || new.cidade else '' end,
      'data', jsonb_build_object(
        'tipo', 'inicio_actividade',
        'machine_id', new.machine_id,
        'nif', coalesce(new.nif, '')
      )
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_notificar_inicio on public.pings;
create trigger trg_notificar_inicio
after insert on public.pings
for each row execute function public.notificar_inicio_actividade();
```

---

## Fase 4 — Trigger de pedido de ajuda

```sql
create or replace function public.notificar_pedido_ajuda()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  invoke_secret text;
  nome_cliente text;
  localidade_cliente text;
begin
  -- 1. Buscar secret. Silêncio em caso de ausência.
  select decrypted_secret into invoke_secret
  from vault.decrypted_secrets
  where name = 'edge_invoke_secret';
  if invoke_secret is null then return new; end if;

  -- 2. Se conseguirmos, dar nome humano ao push (não NIF/machine_id).
  select nome, localidade into nome_cliente, localidade_cliente
  from clientes
  where id = new.cliente_id
     or (new.cliente_id is null and nif = new.nif)
  limit 1;

  -- 3. Disparar push. Título é "Pedido de ajuda"; corpo tem nome + local + preview.
  perform net.http_post(
    url := 'https://oefqbkhioncakojipqyx.supabase.co/functions/v1/enviar-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || invoke_secret
    ),
    body := jsonb_build_object(
      'title', 'Pedido de ajuda',
      'body',
        coalesce(nome_cliente, 'NIF ' || coalesce(new.nif, '?')) ||
        coalesce(' — ' || localidade_cliente, '') ||
        case
          when new.notas is not null and length(trim(new.notas)) > 0
            then ': ' || left(trim(new.notas), 80)
          else ''
        end,
      'data', jsonb_build_object(
        'tipo', 'pedido_ajuda',
        'pedido_id', new.id,
        'machine_id', new.machine_id,
        'nif', coalesce(new.nif, '')
      )
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_notificar_pedido_ajuda on public.pedidos_ajuda;
create trigger trg_notificar_pedido_ajuda
after insert on public.pedidos_ajuda
for each row execute function public.notificar_pedido_ajuda();
```

---

## Fase 5 — Testes SQL

### 5.1 Simular ping de máquina nova (deve disparar push)

```sql
-- Ping de máquina sem licença → deve disparar push "Novo terminal a comunicar".
insert into pings (machine_id, nif, versao, cidade)
values ('teste_' || gen_random_uuid(), '999999990', '1.6.5', 'Setúbal');
```

Verificar nos logs da Edge Function (`get_logs` no MCP ou dashboard) que houve invocação e o payload correcto.

### 5.2 Simular segundo ping do mesmo machine_id (NÃO deve disparar)

```sql
-- Repetir o mesmo machine_id → não deve haver push (já foi notificado).
insert into pings (machine_id, nif, versao, cidade)
values ('<mesmo_machine_id_do_5.1>', '999999990', '1.6.5', 'Setúbal');
```

Sem invocação nova nos logs. Confirma que a deduplicação funciona.

### 5.3 Simular pedido de ajuda (deve disparar push)

```sql
-- Pedido de ajuda de cliente existente → push "Pedido de ajuda: NomeCliente…"
insert into pedidos_ajuda (machine_id, nif, notas)
values (
  '<machine_id_de_um_cliente_existente>',
  '<nif_desse_cliente>',
  'A impressora térmica não está a imprimir talões desde ontem.'
);
```

Verificar log da Edge Function: título "Pedido de ajuda", body com nome do cliente + preview das notas.

### 5.4 Limpeza dos dados de teste

```sql
-- Remover os pings e pedidos_ajuda de teste.
delete from pings where machine_id like 'teste_%';
delete from pedidos_ajuda where nif = '999999990';
```

---

## Fase 6 — Verificação end-to-end (no telemóvel)

Depois da Fase 5 estar verde:

1. Ter a app WashInvoice Control aberta no telemóvel (para receber SnackBar em foreground) OU fechada (para receber notificação nativa).
2. Repetir 5.1 (ping de máquina nova). Push deve chegar ao telemóvel em segundos.
3. Repetir 5.3 (pedido de ajuda). Push deve chegar com o formato "Pedido de ajuda: …".
4. Limpar 5.4.

Registar resultado em `docs/verificacao_trigger_push.md`.

---

## Fase 7 — Reconciliação da documentação

No fim:

1. Actualiza `docs/estado_e_roadmap.md`:
   - Marca Task 19 como concluída na secção "O que foi entregue" (nova ronda "Trigger DB automático").
   - Remove da secção "Curto prazo" o item "Trigger DB automático (pendente)".
2. Se algum passo do prompt não correu como descrito, regista em secção nova `## Reconciliação` no fim deste próprio ficheiro (`prompt_trigger_push_backend.md`).

---

## Rollback (só em caso de emergência)

Se algum trigger causar problemas em produção (ex: pings a falhar em cadeia):

```sql
-- Desactivar triggers sem apagar código (permite investigar depois).
alter table pings          disable trigger trg_notificar_inicio;
alter table pedidos_ajuda  disable trigger trg_notificar_pedido_ajuda;

-- Reactivar quando resolvido:
-- alter table pings         enable trigger trg_notificar_inicio;
-- alter table pedidos_ajuda enable trigger trg_notificar_pedido_ajuda;

-- Ou apagar tudo (nuclear):
-- drop trigger trg_notificar_inicio       on pings;
-- drop trigger trg_notificar_pedido_ajuda on pedidos_ajuda;
-- drop function notificar_inicio_actividade();
-- drop function notificar_pedido_ajuda();
```

---

## NÃO TOCAR EM

- Edge Function `enviar-push` — funciona, não mudar.
- Edge Function `assinar-documento` — do POS, fora do âmbito.
- Tabela `admin_dispositivos` — mantém-se.
- Tabelas `licencas`, `clientes` — este trigger só faz SELECT delas, nunca UPDATE.
- Secret `EDGE_INVOKE_SECRET` nos Edge Function Secrets — mantém-se (a Edge Function continua a lê-lo de lá). O vault é para o Postgres poder aceder ao mesmo valor a partir do trigger.

---

## Regras

- Português europeu nos textos do push que aparecem ao Cesar.
- Silêncio em falhas: se o secret não estiver no vault, se o `pg_net` estiver down, se a Edge Function devolver erro — o trigger tem que falhar silenciosamente para não bloquear o INSERT original (ping/pedido). Objectivo: o INSERT sempre passa; o push é *best-effort*.
- Sem retry manual — se um push falhar, perde-se. Não vale o overhead de fila.
