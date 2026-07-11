# Verificação de RLS — WashInvoice Control

Registo das verificações do Row Level Security definido em
[`rls_policies.sql`](./rls_policies.sql).

> **Estado atual: ⏳ PENDENTE DE APLICAÇÃO.**
> O `rls_policies.sql` ainda **não foi aplicado** ao Supabase no momento em que
> este documento foi criado. As verificações abaixo são o protocolo a executar
> **depois** de aplicar. Cada uma tem de ficar com evidência (log/print) e a data.

---

## ⚠️ Pré-requisito que ISTO exige (fora do âmbito desta ronda)

Aplicar o RLS **corta o acesso anónimo a `licencas`**. Se o WashFactura POS hoje
lê a sua licença pela **anon key filtrando por `machine_id`**, esse caminho
**deixa de funcionar** assim que o RLS é aplicado — por desenho.

Isto é **seguro de aplicar agora** apenas porque **não há terminais em produção**
(confirmado: só demo/dev). Antes de qualquer terminal real ir para produção, o
POS **tem de** passar a:

1. Autenticar no Supabase com as suas credenciais (email+password geradas na
   emissão, entregues out-of-band).
2. Ler a sua licença **sem** filtrar por `machine_id` — o RLS já a limita a
   `user_id = auth.uid()`.
3. Inserir `pings`/`aceites_termos`/`pedidos_renovacao` **autenticado** (a policy
   valida que o `machine_id` pertence a uma licença do próprio `auth.uid()`).
4. Máquinas **pré-licença** (sem credenciais) enviam o primeiro ping pelo RPC
   `registar_ping_inicial(...)` via anon.

**TODO POS (ronda separada):** migrar leitura de licença de "anon + machine_id"
para "authenticated + auth.uid()", e ping inicial para o RPC.

---

## Passos manuais antes de verificar

1. Aplicar `rls_policies.sql` no SQL Editor do Supabase.
2. Registar o utilizador admin (Cesar): criar em Authentication → Users e inserir
   o UUID em `public.admins` (secção 6 do `rls_policies.sql`).
3. Criar um utilizador Auth de **teste do POS** (não-admin) e emitir/atribuir-lhe
   uma licença demo com `licencas.user_id = <uuid do POS de teste>`.

---

## Estado de RLS registado (output das queries de estado)

Colar aqui o resultado de:

```sql
select tablename, rowsecurity from pg_tables
where schemaname='public' order by tablename;

select tablename, policyname, cmd, roles from pg_policies
where schemaname='public' order by tablename, policyname;
```

**Antes de aplicar:** _(colar output)_
**Depois de aplicar:** _(colar output — esperado: rowsecurity=true nas 5 tabelas + as policies de `rls_policies.sql`)_

---

## Baseline pré-aplicação (sonda read-only já executada)

Sonda anónima às 5 tabelas **antes** de aplicar RLS (só leitura, sem escrita):

```
GET /rest/v1/<tabela>?select=*  (apikey=anon)
→ licencas / clientes / pings / pedidos_renovacao / aceites_termos
  todas: HTTP 200, count */0, body []
```

Ambíguo por si só (tabelas demo podem estar vazias), por isso o discriminador
real é a re-execução **pós-aplicação** dos checks 4a/4c/4d abaixo.

---

## Verificações do Control autenticado (admin) — UI

Requer app a correr, login com o utilizador admin. Anexar print de cada uma.

| # | Ação | Esperado | Evidência | Data |
|---|------|----------|-----------|------|
| 1a | Listar licenças (Dashboard/Instalações) | Lista carrega | ☐ | |
| 1b | Criar licença (Iniciar atividade) | Criada; aparece na lista | ☐ | |
| 1c | Marcar como pago e renovar (Detalhe) | Validade atualizada | ☐ | |
| 1d | Editar/criar cliente | Guardado | ☐ | |
| 1e | Ver pings / histórico | Pings visíveis | ☐ | |
| 1f | Abrir Detalhe do cliente | Abre com licença+pings+termos | ☐ | |

> Nota: com o RLS ligado, estas ações **só funcionam** depois do passo manual 2
> (utilizador em `admins`). Sem isso, `is_admin()` é false e o Control autenticado
> recebe 0 linhas / erros de escrita — o que é, em si, um sinal de que o RLS está
> ativo.

## Verificação — Control SEM autenticar

| # | Ação | Esperado | Evidência | Data |
|---|------|----------|-----------|------|
| 2 | Abrir a app sem sessão | Mostra LoginScreen; nenhum ecrã de dados acessível | ☐ | |

(Ao nível da API, cobre-se pelo check 4a.)

## Verificações de isolamento (API, anon e POS) — comandos

Substituir `ANON_KEY` pela chave em `lib/core/supabase_config.dart` e os tokens
de POS pelos JWT obtidos via login dos utilizadores de teste.

**4a — anon NÃO lê `licencas`** (esperado: `[]`, sem linhas):
```bash
curl -s "https://oefqbkhioncakojipqyx.supabase.co/rest/v1/licencas?select=*" \
  -H "apikey: ANON_KEY" -H "Authorization: Bearer ANON_KEY"
# Esperado depois de aplicar: []  (RLS bloqueia; anon não tem policy)
```

**4b — POS A NÃO lê licença de POS B** — ⏳ **TODO (ronda de migração do POS).**
Adiado por decisão do Cesar: exige criar dois utilizadores Auth de teste no
Dashboard (o Code não tem `service_role` nem Dashboard). Justificado porque o POS
**ainda não autentica de todo** — não há POS real para testar A vs B. Fica coberto
quando o POS migrar para leitura autenticada por `auth.uid()`. Comando de
referência para essa altura:
```bash
# Autenticar como POS_A e pedir licencas: só devolve a linha com user_id = A.
curl -s "https://oefqbkhioncakojipqyx.supabase.co/rest/v1/licencas?select=*" \
  -H "apikey: ANON_KEY" -H "Authorization: Bearer JWT_DO_POS_A"
# Esperado: 1 linha (a de A). A de B nunca aparece.
```

**4c — ping inicial via RPC (anon) FUNCIONA**:
```bash
curl -s -X POST \
  "https://oefqbkhioncakojipqyx.supabase.co/rest/v1/rpc/registar_ping_inicial" \
  -H "apikey: ANON_KEY" -H "Authorization: Bearer ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"p_machine_id":"verif-anon","p_nif":"500009999","p_versao":"1.5",
       "p_lat":38.72,"p_lon":-9.13,"p_cidade":"Lisboa","p_metodo_geo":"gps"}'
# Esperado: 204/200 e o ping aparece na tabela pings.
```

**4d — INSERT direto em `pings` como anon FALHA**:
```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  "https://oefqbkhioncakojipqyx.supabase.co/rest/v1/pings" \
  -H "apikey: ANON_KEY" -H "Authorization: Bearer ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"machine_id":"verif-anon-direto","nif":"500009999"}'
# Esperado depois de aplicar: 401/403 (violação de RLS). Anon não tem policy INSERT.
```

| # | Check | Esperado | Resultado | Data |
|---|-------|----------|-----------|------|
| 4a | anon SELECT `licencas` | `[]` / negado | ☐ | |
| 4b | POS A lê licença de B | falha (0 linhas de B) | ⏳ TODO (ronda POS) | |
| 4c | RPC `registar_ping_inicial` (anon) | sucesso | ☐ | |
| 4d | INSERT direto `pings` (anon) | 401/403 | ☐ | |

---

## Limpeza pós-verificação

Apagar os pings de verificação:
```sql
delete from public.pings where machine_id in ('verif-anon','verif-anon-direto');
```
