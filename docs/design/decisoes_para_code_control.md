# Decisões para retomar a Fase 2 do prompt de painel remoto

> Cola isto directamente na sessão parada do Code do Control (aberta em `D:\WashInvoiceControl\washinvoice_control\`).

O trabalho paralelo do Code do POS aplicou por engano algumas das migrations que este prompt tinha planeado. Todas idempotentes (`if not exists`). Retoma sem repetir.

## Migrations JÁ APLICADAS na Supabase (não voltar a aplicar)

- `alter table licencas add column tier text not null default 'base'` — pronta.
- `alter table licencas add column preferencias_features jsonb not null default '{}'` — pronta.
- `alter table licencas_audit add column acao text` — pronta.
- `alter table licencas_audit add column parametros jsonb` — pronta.
- `alter table pings add column estado_licenca text, termos_aceites boolean, ip_publico text, origem text` — pronta.

Confirma tu (execute_sql via MCP) antes de assumir. Se por acaso alguma coluna faltar, aplica-a idempotente.

## Correcções ao prompt original

### 1) Não criar `audit_licencas`

O prompt pedia uma tabela nova. Já existe `public.licencas_audit` alimentada por trigger, agora estendida com `acao` e `parametros`. Usa esta.

- O modal de historial (Fase 3.3) lê de `licencas_audit` filtrado por `licenca_id` (join com `licencas.machine_id`).
- A Edge Function `gerir-licenca` insere directamente em `licencas_audit` com `acao` e `parametros` preenchidos. `actor_uid`, `actor_role`, `antes`, `depois`, `campos_alterados` também têm de ficar populados (a trigger existente cobre a maioria em updates directos, mas como a function escreve com service_role, valida caso a caso).

### 2) Usar `tier`, não `plano`

Onde o prompt original dizia mudar `plano` para `base|pro`, ler `tier`.

- Coluna `licencas.tier` é a fonte da verdade para nível comercial.
- `licencas.plano` fica intocado — semântica de duração (`mensal`, `trimestral`, `anual`), faz parte da assinatura HMAC do POS.
- Acção `mudar_plano` da Edge Function passa a chamar-se **`mudar_tier`**, aceita `parametros: { tier: "base" | "pro" }`, escreve em `licencas.tier`.
- Chip do plano na UI mostra `licencas.tier` (`Base` cinza, `Pro` dourado). Ignora `licencas.plano` para efeitos de tier.

### 3) `gerir-licenca` — auth explícita de admin

- `verify_jwt: true` no `config.toml` da function.
- Dentro da function, chamar `is_admin(user.id)` (o SECURITY DEFINER que já existe em `rls_policies.sql`). Se retornar `false` → 403.
- Copiar o padrão de `is_admin` que já existe; não improvisar.

### 4) Migrar todas as writes de `licencas_repository.dart` para `gerir-licenca`

Hoje `licencas_repository.dart` tem 4 mutações que escrevem com anon+JWT:
- `criar()` — mantém (não é gestão remota, é onboarding manual do Cesar; opcional migrar).
- `definirSerie()` — mantém por agora (série é fluxo separado); deixa nota que idealmente vai também para função dedicada.
- `activar()` — **substituir** por `GerirLicencaService.suspender()` / `reactivar()`.
- `actualizar()` — **substituir** por chamadas granulares (`prolongar`, `mudar_tier`, etc.).

Qualquer caller (search em `lib/`) dessas mutações refactoriza para chamar `GerirLicencaService`.

### 5) Card "Preferências do admin" (read-only) — tem dados

`licencas.preferencias_features` está criada. Lê da linha da licença, não é opcional. Se JSONB estiver vazio (`{}`), mostra as 3 features com estado default (todas ligadas para `tier=pro`, todas escondidas para `tier=base` — usa a mesma regra do `featureVisivel` do POS).

## Ordem de execução (sem gates intermédios)

1. Confirmar via `execute_sql` que as colunas mencionadas acima existem. Se alguma faltar, aplicar `add column if not exists`.
2. Migration extra: nenhuma (não criar `audit_licencas`).
3. Deploy Edge Function `gerir-licenca` (Fase 2 do prompt original) com estas 3 mudanças: (a) `verify_jwt: true` + `is_admin()` check, (b) acção renomeada `mudar_plano` → `mudar_tier`, (c) `mudar_tier` escreve em `licencas.tier`, e a auditoria vai para `licencas_audit`.
4. `GerirLicencaService` no cliente (Fase 3 do prompt original) — renomear método `mudarPlano` → `mudarTier`.
5. UI `DetalheClienteScreen` (Fase 4 do prompt original) — chip de plano lê `licencas.tier`, botão passa a `Mudar para Pro / Mudar para Base` mas invoca `mudarTier`.
6. Historial lê `licencas_audit` (Fase 4.3 do prompt original, substituindo `audit_licencas`).
7. Shortcuts em `InstalacoesScreen` (Fase 5 do prompt original) — sem alterações.
8. Testes (Fase 6 do prompt original) — actualizar assertions para reflectir `tier` em vez de `plano`.
9. Refactor de callers de `licencas_repository.dart` mutations (`activar()`, `actualizar()`).
10. Reconciliação.

## Único gate

Reporta SHAs no fim. Cesar faz teste manual (Fase 7 do prompt original) e autoriza merge no chat.

## Restrições reiteradas

- **NÃO fechar RLS** de `licencas` (gate manual do Cesar noutro prompt).
- **NÃO escrever em `licencas`** com anon key. Toda mutação passa por `gerir-licenca`.
- **NÃO alterar auth** do Control.
- **NÃO alterar preferências individuais** de features do lado do Control — só read-only.
- **NÃO criar** `audit_licencas` — usar `licencas_audit`.
- **NÃO pedir OK** para migrations aditivas ou deploy de function — autorização dada.

Segue.
