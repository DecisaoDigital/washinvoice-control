# Contrato Supabase — WashInvoice (POS) ↔ WashInvoice Control (Admin)

> **Estado desta análise:** produzida em 2026-07-11 com base no código real de ambas as apps (POS `lib/` extraído para revisão, Control neste repo) + inspecção directa das tabelas, policies e Edge Functions do projeto Supabase `oefqbkhioncakojipqyx`.
> **Porquê este documento existe:** o desenho de RLS em `rls_policies.sql` assume que o POS autentica no Supabase. Não autentica. Este documento fixa o contrato real e assinala onde o SQL preparado colide com ele antes de ser aplicado.

---

## 1. As duas apps, em uma linha

- **WashInvoice / WashFactura (POS):** Flutter/Windows, base local SQLite. Único responsável fiscal.
- **WashInvoice Control:** Flutter/Android, admin remoto do Cesar para emitir e monitorizar licenças.

Ambas falam com **o mesmo projeto Supabase** (`oefqbkhioncakojipqyx`, região `eu-central-1`). Não partilham base de dados operacional — só o backend de licenciamento e assinatura fiscal.

---

## 2. O que o POS faz no Supabase (real, verificado no código)

Ficheiros analisados: `lib/core/supabase_config.dart`, `lib/services/licenca/licenca_service.dart`, `lib/services/licenca/licenca_assinatura.dart`, `lib/services/fiscal/assinador_remoto.dart`, `lib/services/signing/remote_pdf_signature_service.dart`.

### 2.1 Autenticação

**O POS NUNCA faz login.** Nunca chama `signInWithPassword`, nunca cria sessão. Todo o tráfego Supabase é feito com a `anon` key (hardcoded em `SupabaseConfig`, marcada explicitamente como pública por design). Consequência: no Supabase o POS é sempre `role = anon`, sem `auth.uid()`.

### 2.2 Operações sobre tabelas

| Tabela | Operação | Como | Bloqueante? | Notas |
|---|---|---|---|---|
| `pings` | INSERT | Direto via anon, `.from('pings').insert({...})` | **Não** (fire-and-forget, `try/catch` engolido) | Arranque + a cada 6 h. Payload: `machine_id, nif, versao, lat, lon, cidade`. |
| `aceites_termos` | INSERT | Direto via anon, `.from('aceites_termos').insert({...})` | **Não** (fire-and-forget) | Uma vez, no aceite dos termos. Payload: `machine_id, nif, versao_termos, data_aceite, cidade`. |
| `licencas` | SELECT | `.from('licencas').select('activa').eq('machine_id', X).maybeSingle()` | **Não** — se falhar ou vier `null`, confia no `licenca.json` local. | "Corte remoto": permite ao Cesar desactivar uma licença marcando `activa=false`. Se o RLS bloquear (nem devolve `null`, devolve `[]` → `maybeSingle → null`), o POS trata como "sem registo → não bloqueia". |

**O POS não faz UPDATE nem DELETE em lado nenhum.** Não escreve em `clientes`, `pedidos_renovacao`, `assinaturas_log`, `company_signature_settings`, `invoice_signature_logs`.

### 2.3 Edge Functions

| Função | Chamada por | Como | Faz |
|---|---|---|---|
| `assinar-documento` | POS (produção) | `Supabase.instance.client.functions.invoke('assinar-documento', body: {machine_id, texto})` via anon | Recebe machine_id + texto (Portaria 363/2010). Valida licença em `licencas` usando `SERVICE_ROLE_KEY` (ignora RLS). Assina com RSA + SHA-1 (chave privada só no secret `RSA_PRIVATE_KEY` do Supabase). Regista metadados em `assinaturas_log`. Devolve `{ assinatura: base64 }`. |
| `assinar-pdf` | POS (código preparado) | Mesma via | **Ainda não existe no Supabase** (só `assinar-documento` está deployada). TODO conhecido para QES via provedor externo. |

**A chave RSA privada vive só como secret da Edge Function.** Nunca chega ao cliente. Isto está bem feito.

**A chave HMAC do `licenca.json` está no binário do POS** (`licenca_assinatura.dart:14`, `_hmacKey`). Isto é o teatro de segurança que a ronda "Edge Function + Ed25519" tem de resolver. Qualquer pessoa que extraia o binário Windows consegue emitir licenças válidas.

---

## 3. O que o Control faz no Supabase (real, verificado no código)

Ficheiros analisados: `lib/core/supabase_config.dart`, `lib/features/auth/login_screen.dart`, `lib/main.dart`, `lib/repositories/*`, `lib/services/licenca_emissao.dart`.

### 3.1 Autenticação

**O Control autentica.** `signInWithPassword(email, password)` no `LoginScreen`; sessão persistida por `Supabase.initialize`; guard no router força login antes de qualquer ecrã. Uma vez autenticado, o Cesar é `role = authenticated` com `auth.uid()` conhecido.

### 3.2 Operações sobre tabelas (autenticado como Cesar)

| Tabela | Operações | Origem no código |
|---|---|---|
| `clientes` | SELECT, INSERT, UPDATE | `clientes_repository.dart` |
| `licencas` | SELECT (todas + por NIF + por machine_id + activas com série), INSERT, UPDATE | `licencas_repository.dart`, `licenca_emissao.dart` |
| `pings` | SELECT (últimos por instalação, últimos por machine_id) | `pings_repository.dart` |
| `pedidos_renovacao` | SELECT (pendentes), UPDATE (`confirmar`) | `pedidos_renovacao_repository.dart` |
| `aceites_termos` | SELECT (último por machine_id) | `aceites_termos_repository.dart` |

**Nenhum repositório do Control chama `.delete()`.** DELETE não é usado em lado nenhum hoje.

### 3.3 Emissão de licenças

Feita **inteiramente no cliente** (`licenca_emissao.dart`): assina com HMAC (mesma chave do POS, cópia verbatim), constrói `licenca.json`, verifica colisão de série via SELECT. O UUID `auth.users` do POS **não é criado** — o Control não tem código para provisionar utilizadores.

---

## 4. Contrato actual, esquematizado

```
┌──────────────────────────┐                         ┌──────────────────────────┐
│      WashInvoice POS     │                         │  WashInvoice Control     │
│      (anon key only)     │                         │  (authenticated Cesar)   │
└────────────┬─────────────┘                         └────────────┬─────────────┘
             │                                                    │
             │ INSERT pings (anon, fire-and-forget)                │
             │ INSERT aceites_termos (anon, fire-and-forget)       │
             │ SELECT licencas.activa (anon, best-effort)          │
             │ invoke assinar-documento (anon → Edge Function)     │
             │                                                    │
             ▼                                                    ▼
       ┌──────────────────────────────────────────────────────────────┐
       │                       Supabase                               │
       │                                                              │
       │   Tabelas         Edge Functions       Secrets                │
       │   ─────────       ──────────────       ──────────────────     │
       │   licencas        assinar-documento    RSA_PRIVATE_KEY        │
       │   pings                                SUPABASE_SERVICE_ROLE  │
       │   aceites_termos                                              │
       │   pedidos_renovacao   (assinar-pdf     [licenca.json HMAC:    │
       │   clientes             não existe       chave no binário POS  │
       │   assinaturas_log      ainda)           — teatro segurança]   │
       │   company_signature_settings                                  │
       │   invoice_signature_logs                                      │
       └──────────────────────────────────────────────────────────────┘
                             ▲
                             │ SELECT/INSERT/UPDATE várias tabelas
                             │ (JWT do Cesar)
                             │
                       ┌──────────────────────┐
                       │      Control         │
                       └──────────────────────┘
```

---

## 5. Divergência crítica — `rls_policies.sql` vs realidade

O `rls_policies.sql` preparado pelo Code assume **Opção D**: cada POS autentica no Supabase com credenciais próprias, RLS via `auth.uid()`. **Isso não corresponde ao POS actual.** O POS é anon-only e não é âmbito desta ronda mudá-lo.

Aplicar o SQL como está **parte silenciosamente** os seguintes fluxos do POS:

| Fluxo do POS | Estado hoje | Após o SQL do Code |
|---|---|---|
| INSERT em `pings` (anon direto) | ✅ Funciona (policy `insert_pings` para `public` com `with_check: true`) | ❌ **Bloqueado** — a nova policy `pings_insert` só aceita `authenticated` (admin ou POS logado). Anon fica sem caminho. |
| INSERT em `aceites_termos` (anon direto) | ✅ Funciona | ❌ **Bloqueado** — mesmo problema. |
| SELECT `licencas.activa` (anon direto) | ⚠️ Já falhava (policy antiga só para authenticated). POS trata como "sem registo → não bloqueia". | ⚠️ Continua a falhar, comportamento igual. Sem regressão. |
| Edge Function `assinar-documento` | ✅ Funciona (Edge Function usa service_role, ignora RLS) | ✅ Continua a funcionar. |

O RPC `registar_ping_inicial` que o Code criou para o caso "pré-licença" **não é chamado por nenhuma versão do POS**. O POS chama `.from('pings').insert(...)` directamente. Portanto o RPC fica no Supabase sem consumidor.

**Consequência prática:** a partir do momento em que o SQL for aplicado, todos os pings do POS deixam de chegar ao Supabase (silenciosamente — o POS engole a falha). O dashboard do Control deixa de ver terminais a comunicar. Aceites de termos também deixam de ser registados remotamente (o registo local sobrevive).

---

## 6. Além disso — duas tabelas de assinatura fiscal ficaram fora

`company_signature_settings` e `invoice_signature_logs` **têm RLS desligado** hoje (expostas a qualquer anon com a URL do projeto). O `rls_policies.sql` não as toca porque foram acrescentadas do lado fiscal do POS (provavelmente para o fluxo QES/`assinar-pdf`). Precisam de ser tratadas.

Modelo proposto para estas duas (mesmo espírito de `assinaturas_log`):

- `alter table … enable row level security`
- SELECT apenas para admin (via `is_admin()`)
- INSERT/UPDATE apenas via Edge Function com service_role (nenhuma policy anon/authenticated → só service_role passa)
- Nenhum DELETE

Confirmar antes de aplicar: são de produção real ou código WIP do fluxo QES? Se WIP, aceitável ligar RLS sem policies (fica selado até haver função) — mas hoje estão abertas.

---

## 7. Recomendação — o que fazer antes de aplicar RLS

**Duas opções, com trade-off honesto:**

### Opção A — Manter o POS como está (anon-only). Ajustar o SQL.

Menos trabalho, respeita o desenho actual do POS. Mudanças ao `rls_policies.sql`:

1. **Manter policies anon abertas para os INSERTs do POS**:
   ```sql
   create policy pings_insert_anon on public.pings
     for insert to anon with check (true);
   create policy aceites_insert_anon on public.aceites_termos
     for insert to anon with check (true);
   ```
   Perde-se isolamento por máquina (qualquer anon pode inserir ping com qualquer `machine_id`). Aceitável enquanto o fluxo pré-licença for legítimo.
2. **Remover o RPC `registar_ping_inicial`** — sem consumidor.
3. **Manter SELECT bloqueado a anon em `licencas`** (o POS já lida com isso).
4. **Manter tudo o resto** (admin via `is_admin()`, isolamento POS-autenticado via `user_id` — como preparação para o dia em que o POS migrar).
5. Ligar RLS em `company_signature_settings` e `invoice_signature_logs`.

Consequência de segurança: qualquer pessoa com a anon key pode fazer flood de pings/aceites. Mitigação: rate-limit ao nível da API do Supabase (documentar como TODO).

### Opção B — Migrar o POS para autenticar (grande refactor)

Cada terminal ao instalar recebe credenciais próprias no `licenca.json`. O POS chama `signInWithPassword` no arranque (com fallback anon para instalações pré-licença). RLS por `auth.uid()` como o Code desenhou.

Requer mudar código do POS. Fora do âmbito prometido nesta ronda (a promessa foi "não tocar no POS"). Fica para roadmap.

**Recomendação: Opção A agora.** Manter esta ronda focada em "não partir o POS" enquanto se resolve a segurança admin (RLS séria em `licencas`, `clientes`, `pedidos_renovacao`, `admins`). O caminho para Opção B fica documentado como próxima migração major do POS.

---

## 8. Além do RLS — a chave HMAC no binário do POS

Mesmo com RLS perfeito, a maior brecha continua a ser a `_hmacKey` no `licenca_assinatura.dart` do POS: quem extrai o binário emite licenças. Isto é o item nº1 do roadmap (Edge Function `emitir_licenca` + Ed25519). Não é resolúvel só com policies do Supabase.

---

## 9. Roadmap de segurança (por ordem de urgência)

1. **Ajustar `rls_policies.sql` para Opção A** e cobrir as duas tabelas de assinatura → aplicar → verificar pings e aceites continuam a chegar ao Supabase a partir de um POS demo.
2. **Edge Function `emitir_licenca` + `revogar_licenca` + assinatura Ed25519.** Chave privada só como secret Supabase. `assinar-documento` já mostra que este padrão funciona no projeto.
3. **Migrar POS para Ed25519** (`pointycastle` ou similar para validar chave pública). Deprecar HMAC.
4. **Opção B (opcional, longo prazo):** POS a autenticar-se por terminal, RLS por `auth.uid()`, rate-limit dispensável.

---

## 10. Nada a mudar no POS **nesta ronda**

Regra washinvoice #1 (não inventar/tocar no que não está no âmbito). O POS mantém-se anon-only. Todas as mudanças propostas neste documento são no Supabase (policies + Edge Functions futuras) e no Control (Ed25519 na ronda seguinte). O código do POS só será tocado quando a Edge Function `emitir_licenca` estiver pronta e a migração para Ed25519 for feita — ronda própria, prompt próprio, "NÃO TOCAR EM" próprio.
