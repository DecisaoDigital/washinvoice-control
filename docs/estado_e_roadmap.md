# WashInvoice Control — Estado e Roadmap

> Documento vivo. Actualizar sempre que uma ronda fechar ou uma decisão de arquitectura mudar.
> Última actualização: 2026-07-22 (hora local nos timestamps — v1.6.3, #101).

---

## 1. O que é isto

**WashInvoice Control** — app Android (Flutter + Riverpod + Supabase) usada só pelo Cesar (admin único) para:

- Emitir e gerir licenças do POS WashInvoice/WashFactura (Windows).
- Ver terminais a comunicar (pings) em tempo próximo do real.
- Atender leads de instalações novas (fluxo "Início de actividade").
- Receber notificações push quando algo relevante acontece.

**Não é o produto vendido** — o produto é o POS WashFactura. O Control é ferramenta interna de operação comercial.

Marca comercial: **WashInvoice**. "WashControl" é nome interno para diferenciar internamente o companion Android do POS Windows.

---

## 2. Stack e projectos

| Componente | Detalhes |
|---|---|
| Control (Android) | Flutter 3.8+, Riverpod, Supabase, Firebase Messaging. Repo local: `D:\WashInvoiceControl\washinvoice_control`. Branch de trabalho: `feature/melhorias-r1-r2` (por fazer merge). |
| POS WashFactura (Windows) | Flutter + Drift/SQLite. Fora do escopo deste repo. Versão em desenvolvimento: **1.6.6**. Pré-certificação AT. |
| Supabase | Projecto `oefqbkhioncakojipqyx` (região `eu-central-1`). URL: `https://oefqbkhioncakojipqyx.supabase.co`. |
| Firebase / GCP | Projecto `washinvoice-control` (plano Spark, grátis). Só usado para FCM push. |
| Notificações push | FCM v1. Edge Function `enviar-push` no Supabase; token registado em `admin_dispositivos`. |

---

## 3. Tabelas Supabase relevantes

| Tabela | Papel | RLS |
|---|---|---|
| `clientes` | Dados de cada lavandaria (+ `localidade` humana desde v1.4) | Policy actual: `authenticated` acesso total. Ronda RLS Opção D preparada mas não aplicada. |
| `licencas` | Uma linha por terminal instalado | idem |
| `pings` | Telemetria de POS (fire-and-forget do POS via anon key) | INSERT anon aberto (para o POS conseguir escrever) |
| `aceites_termos` | Aceites RGPD (uma linha por instalação) | INSERT anon aberto |
| `pedidos_renovacao` | Pedidos de renovação criados pelo POS | INSERT anon aberto |
| `assinaturas_log` | Log da Edge Function `assinar-documento` | Só SELECT authenticated |
| `company_signature_settings` | Config QES por empresa | RLS ligado (v1.4.3): SELECT authenticated; escrita só service_role |
| `invoice_signature_logs` | Log de assinaturas QES por factura | RLS ligado (v1.4.3): SELECT authenticated; escrita só service_role |
| `admins` | Lista de user_ids com privilégios admin | **Não existe hoje.** Ficará quando aplicarmos RLS Opção A/D pós-AT. |
| `admin_dispositivos` | Tokens FCM dos dispositivos do admin (Cesar) | `authenticated`, cada user só toca no seu token |
| `pedidos_ajuda` | Pedidos de ajuda do cliente (POS insere; Control resolve) | INSERT anon aberto; SELECT/UPDATE authenticated (v1.4) |
| `sugestoes` | Sugestões do cliente (POS insere; Control lê/marca/arquiva) | INSERT anon aberto; SELECT/UPDATE authenticated (v1.4) |
| `licencas_audit` | Auditoria de `licencas` (INSERT/UPDATE/DELETE com actor, campos alterados, antes/depois JSONB) via trigger `trg_audit_licencas` (v1.4.3) | RLS: SELECT authenticated |

---

## 4. Edge Functions

| Função | Papel | Chave usada | Estado |
|---|---|---|---|
| `assinar-documento` | Assina texto fiscal (Portaria 363/2010) com RSA. Chave privada em secret. Valida licença por `machine_id` via service_role. | Anon key (JWT auto) do POS | Deployed, verify_jwt=true |
| `enviar-push` | Recebe `{title, body, data?}`, gera JWT OAuth2 do Google, chama FCM v1, envia para o admin registado | Autenticação custom via `EDGE_INVOKE_SECRET` | Deployed, verify_jwt=false, **testada e funcional** |
| `validar-licenca` | POS valida a sua licença ao arranque. Devolve estado + `tier` + `preferencias_features` | Anon/publishable key do POS | Deployed (v2), verify_jwt=true |
| `registar-terminal` | Auto-onboarding: cria linha de trial 5 dias, `tier='base'` | Anon/publishable key do POS | Deployed (v2), verify_jwt=true |
| `sincronizar-empresa` | POS envia ficha da empresa + preferências de features | Anon/publishable key do POS | Deployed, verify_jwt=true |
| `gerir-licenca` | **Control** muda licenças: prolongar, definir validade, suspender, reactivar, cancelar, mudar tier. Auditado em `licencas_audit` | JWT do admin (anon key sozinha → 401) | Deployed (v2), verify_jwt=true + `is_admin()` |

> **v1.4.3:** as Edge Functions passam a estar **versionadas no repo** em
> `supabase/functions/` (`enviar-push/`, `assinar-documento/` com `assinatura.ts`,
> + `README.md`) — fonte de verdade. Não redeployar via CLI sem necessidade.

---

## 5. Segredos e ficheiros críticos

**Nunca commitar em git.** Localização e uso:

| Item | Onde vive | Uso |
|---|---|---|
| `google-services.json` | `android/app/google-services.json` (dentro do repo, ignorar em git via `.gitignore` já configurado) | Firebase config do app Android |
| Chave FCM (`washinvoice-control-XXXX.json`) | Disco local do Cesar, fora do repo | Copiada como `FCM_SERVICE_ACCOUNT_JSON` no Supabase secrets. Não voltar a usar directamente. |
| `FCM_SERVICE_ACCOUNT_JSON` | Supabase Edge Function Secrets | Edge `enviar-push` lê e assina JWT OAuth2 |
| `EDGE_INVOKE_SECRET` | Supabase Edge Function Secrets. Valor: `186e626e50b31e4806bfac3ff8b5d9b30a3aa91cbbdf2a7efe8e989222df5470` | Autoriza chamadas a `enviar-push` |
| `RSA_private_key` | Supabase Edge Function Secrets (pré-existente) | Edge `assinar-documento` — POS |
| `admin_user_id` do Cesar | Hardcoded na Edge Function `enviar-push` como fallback: `9e1bfae1-b932-430d-ad41-055cf894ff7f` | Destino default do push quando não vem `user_id` no payload |

---

## 6. O que foi entregue (por ronda)

### Ronda 1.5.0 — KPIs navegáveis + acertos (branch `feature/1.5-kpi-navegavel`)

1. **KPIs do Dashboard clicáveis** — tocar em Activas / Pendentes / A expirar /
   Expiradas abre `InstalacoesPorEstadoScreen` com a lista dessas instalações
   (ou dos pedidos de renovação pendentes). Cards navegam para o DetalheCliente.
2. **Ordem dos KPIs**: Activas, Pendentes, A expirar, Expiradas (v1.4.4).
3. **Identidade consistente do terminal** (v1.4.4): o mesmo terminal mostra a
   mesma etiqueta em todo o lado ("Sem NIF ainda" via `nomeDe`, também no card
   de Início de actividade).
4. Testes: `kpi_navegacao_test`. **72 verdes**. Versão **1.5.0+19**.


### Ronda 1.4.3 — auditoria/segurança backend + melhorias Flutter (branch `feature/1.4.3-melhorias`)

**Backend (aplicado em produção via MCP):**

1. **Edge Functions versionadas no repo** — `supabase/functions/enviar-push/`, `supabase/functions/assinar-documento/` (com `assinatura.ts`), + `README.md`. Passa a ser fonte de verdade.
2. **Índice único parcial `licencas_serie_activa_unique`** — impede duas licenças activas com a mesma série (case/whitespace insensitive).
3. **Tabela `licencas_audit`** + função + trigger `trg_audit_licencas` — regista INSERT/UPDATE/DELETE com actor, campos alterados, antes/depois em JSONB. RLS: SELECT authenticated. Testado com 3 operações (INSERT+UPDATE+DELETE) — as 3 aparecem em audit.
4. **RLS ligado em `company_signature_settings` e `invoice_signature_logs`** — antes expostas a anon. Agora SELECT authenticated, sem INSERT/UPDATE/DELETE público (só service_role da futura Edge `assinar-pdf` passa).

**Flutter (feito):**

5. `DetalheSugestaoScreen` — par do `DetalhePedidoAjudaScreen`; navegação a partir da lista de sugestões. `WiCardTitulo` reutilizável.
6. Dropdown de ordenação nas Instalações (último acesso, nome, validade, localidade) com persistência em SharedPreferences (`instalacoes_ordenacao`). Lógica extraída para `ordenarInstalacoes` (pura, testada).
7. Ecrã de pesquisa global (clientes, licenças, pings, pedidos, sugestões) via ícone de lupa no Dashboard; dados carregados uma vez, filtragem em memória, debounce 250ms.
8. Ecrã de exportação CSV/ZIP (backup) em Sobre/Sistema → "Exportar dados" (`core/csv.dart` UTF-8+BOM; `archive` para o ZIP; partilha via `share_plus`).
9. `descreverErro` trata a `unique_violation` (23505) do índice `licencas_serie_activa_unique` com mensagem legível.
10. Testes: `localidades`/`backup`/`instalacoes_ordenacao`/`detalhe_sugestao`/`pesquisa_global`. **71 verdes**. Versão **1.4.3+17**.
11. **Por fechar**: verificação UI real (`docs/verificacao_apk_r1_4_3.md`).

### Ronda POS 1.6.6 — coordenação com Control (repo POS)

1. **Diálogo Ajuda** — substitui SnackBar em `compra_licenca.dart`. AlertDialog com telefone, email, botão "Enviar email" que gera `mailto:`. Usa constantes `kContacto*`.
2. **Ecrã Pedir Ajuda** — botão que faz INSERT em `pedidos_ajuda` (anon key, fire-and-forget); trigger DB dispara push para o Cesar.
3. **Ecrã Enviar Sugestão** — texto motivador + formulário; ao gravar faz INSERT em `sugestoes` E abre `mailto:` em paralelo.
4. **Campo Localidade** em Dados da Empresa; sync fire-and-forget para `clientes.localidade` no Supabase.
5. Menus de acesso: Pedir Ajuda e Enviar Sugestão acessíveis do menu do POS.
6. **Sem regressões fiscais** — SAF-T, séries, ATCUD, hash chaining intactos.
7. **Por confirmar**: se `ip-api.com` já é chamada com `&lang=pt` (afecta como "Lisboa" chega ao Supabase; se não, fica para 1.6.7).

### Ronda 1.4.2 — conteúdo/apresentação (branch `feature/1.4.2-conteudo`)

Problemas de dados mal tratados (não de render):

1. **`Localidades.traduzir`** (`lib/core/localidades.dart`) — mapa EN→PT para as
   cidades da `ip-api.com` (Lisbon→Lisboa, …). Aplicado em todos os sítios com
   `pings.cidade` (Dashboard, Instalações, DetalheCliente, Mapa, Ativação).
2. **`nomeDe` sem hash** — cascata cliente.nome → nome da licença → `NIF <x>` →
   `Terminal sem identificação`. Nunca o machine_id em listas.
3. **"Sem NIF ainda"** no card de Início de actividade (era "NIF —").
4. **`metodo_geo` null** tratado como `nenhum` (ícone barrado cinza).
5. **Rodapé** do Dashboard sem email (fica no Sobre/Sistema).
6. **`_CardPedidoAjuda`** mostra preview das notas em vez de `Sinal−Localidade`
   (evita "? −" quando o pedido chega sem ping).
7. **`DetalhePedidoAjudaScreen`** — ecrã dedicado (Pedido, Cliente/Terminal,
   Último ping; botões Ligar/Email/Resolver). Dashboard e lista abrem-no.
8. Testes: `localidades_test`, `exibicao_test` (nomeDe sem hash), `dashboard_test`
   ("Sem NIF ainda"). 55 verdes. Versão **1.4.2+16**.
9. **Por fechar**: verificação UI real (`docs/verificacao_apk_r1_4_2.md`).

### Ronda 1.4.1 — fixes pós-instalação (branch `feature/1.4.1-fixes`)

1. **BUG CRÍTICO do Dashboard resolvido.** Raiz: `_KpiRow` usava
   `Row(crossAxisAlignment: stretch)` dentro do `ListView` (altura máxima
   infinita) → a Row ficava com altura infinita; em release renderizava os KPIs
   seguidos de espaço morto enorme (~28 páginas), empurrando todas as secções
   para fora do ecrã. Fix: envolver a Row em `IntrinsicHeight`. Regra genérica
   documentada no `tokens.md`.
2. **Autofill no Login (Task 29)** — `AutofillGroup` + `autofillHints` nos dois
   campos + `TextInput.finishAutofillContext()` no sucesso (dispara o guardar do
   Google Password Manager).
3. **Auto-refresh do Dashboard (Task 30)** — `dashboardRefreshProvider`
   (StreamController); o listener de foreground emite a cada push e o Dashboard
   recarrega (fica montado no IndexedStack → actualiza mesmo noutra tab).
4. **Vibração no aviso em foreground** — `HapticFeedback.mediumImpact()` (o
   SnackBar é silencioso); permissão `VIBRATE` no manifest.
5. **Testes**: 47 verdes (+ `dashboard_test` com red-green verificado do bug do
   scroll infinito, + `login_autofill_test`). Versão **1.4.1+15**.
6. **Por fechar**: verificação UI real (`docs/verificacao_apk_r1_4_1.md`).

### Ronda 1.4.0 — redesign visual + Pedidos de Ajuda + Sugestões (branch `feature/redesign-visual`)

1. **Design tokens em código**: paleta completa (escalas 50/100/200/500/700/900),
   tipografia (`AppText`), `AppSpacing`, `AppRadius`, tema com AppBar `azul900`
   (#1F5F87, reconciliado no `tokens.md`).
2. **8 componentes reutilizáveis** `Wi*` em `lib/core/widgets/` (WiCard,
   WiCardDestaque, WiKpiCard, WiSeccaoTitulo, WiLinhaKV, WiBadgeEstado,
   WiChipFiltro, WiEmptyState) + barrel.
3. **Helpers de exibição** (`exibicao.dart`) e **`ContextoInstalacoes`** — índice
   partilhado licença/cliente/ping por `machine_id`, reutilizado por 4 ecrãs.
4. **Supabase (aplicado em produção)**: coluna `clientes.localidade`, tabelas
   `pedidos_ajuda` e `sugestoes` (com policies anon-insert/admin-rw), trigger
   `limitar_pings_por_maquina` (retém 120 pings/máquina).
5. **Refactor visual** de Dashboard, Instalações, DetalheCliente, Sobre, Login, Mapa.
6. **Ecrãs novos**: Pedidos de Ajuda (Abertos/Histórico) e Sugestões (Por ler/Arquivo).
7. **Versão 1.4.0+14**; Sobre/Dashboard/Login lêem a versão via `PackageInfo`.
8. **Testes**: 43 verdes (exibicao, pedidos_ajuda, sugestoes + os anteriores);
   `flutter analyze` sem avisos novos (só o `anonKey` deprecated pré-existente).
9. **Por fechar**: verificação UI real no telemóvel (`docs/verificacao_apk_r1_4.md`)
   e markers PNG custom do Mapa (TODO — fallback por hue nativo).

### Ronda R1 + R2 — melhorias funcionais no Control (branch `feature/melhorias-r1-r2`)

1. Ecrã **Sobre / Sistema** — versão, ambiente Supabase, sessão, contactos, último ping. Botão terminar sessão.
2. Constantes de contacto em `lib/core/config.dart` — nome, email, telefone da WashInvoice.
3. Função `Dates.adicionarMeses` com regra de fim de mês (corrige transbordo 31 Jan → 2 Mar).
4. `toInsertJson` / `toUpdateJson` separados nos modelos (elimina bug de enviar `id`/`created_at` em UPDATE).
5. Navegação por `machine_id` em vez de NIF (resolve erro com >1 licença por NIF).
6. Filtros no ecrã **Instalações** (estado, versão, cidade, "sem ping há N dias") ao lado da pesquisa existente.
7. Testes: 23/23 verdes (`dates_test.dart`, `models_json_test.dart`, `detalhe_navegacao_test.dart`, + os 10 pré-existentes).
8. Email de acolhimento reescrito, sem IBAN, valoriza produto, contactos na assinatura. Botão: "Enviar email de acolhimento".

### Ronda `trigger_push_backend` — pipeline FCM auto-servido

1. Secret `edge_invoke_secret` guardado no `supabase_vault` (para o Postgres aceder ao mesmo valor que a Edge Function usa).
2. Função `notificar_inicio_actividade()` + trigger `trg_notificar_inicio` em `pings` — dispara push só no PRIMEIRO ping de máquina sem licença (deduplicação embutida). Título "Novo terminal a comunicar" + corpo com NIF/machine_id + cidade.
3. Função `notificar_pedido_ajuda()` + trigger `trg_notificar_pedido_ajuda` em `pedidos_ajuda` — dispara push com nome humano do cliente + localidade + preview das notas.
4. `pg_net.http_post` com header `apikey` (anon key, público) para passar o gateway Cloudflare, e `Authorization: Bearer <edge_invoke_secret>` para a Edge Function validar.
5. Falha silenciosa (`exception when others then return new`) — o INSERT nunca é bloqueado por falha no push.
6. **Testado em produção**: ping novo → HTTP 200, `enviados: 1`, push chegou ao telemóvel do Cesar. Ping repetido → sem invocação (deduplicação OK). Pedido de ajuda → HTTP 200, push com título "Pedido de ajuda" chegou.

### Ronda `push_00_firebase` + `push_01_supabase` + `push_02_control`

1. Projecto Firebase `washinvoice-control` criado.
2. App Android registada (`com.washcontrol.washinvoice_control`).
3. Service account `fcm-sender` com roles: `Firebase Cloud Messaging Admin` + `Firebase Admin` (o segundo necessário para permissão `cloudmessaging.messages.create` da API v1).
4. Extensão `pg_net` activada no Supabase.
5. Tabela `admin_dispositivos` com RLS (cada user só toca no seu token).
6. Edge Function `enviar-push` deployada — gera OAuth2 JWT, chama FCM v1 API, entrega ao dispositivo. Testada com curl, resposta 200 do Google.
7. Cliente Flutter: `firebase_core` + `firebase_messaging` no pubspec, Gradle configurado (`google-services` plugin), permissão `POST_NOTIFICATIONS` no manifest.
8. `lib/services/fcm_service.dart` — inicialização, permissão, obter token, upsert em `admin_dispositivos`, refresh de token, desregistar no logout.
9. `lib/services/fcm_background_handler.dart` — handler top-level para pushes em background.
10. `main.dart` — inicializa Firebase, provider Riverpod sincroniza sessão ↔ registo de token, wrapper `_FcmForegroundListener` mostra SnackBar em foreground.
11. Sobre/Sistema — nova secção "Notificações push" mostra estado do token.
12. **End-to-end validado**: curl → Supabase → FCM → telemóvel do Cesar (SnackBar em foreground, notificação Android em background).

### Documentação criada

- `README.md` (raiz do repo Control) — actualizado no fim do R1.
- `docs/verificacao_apk_r1.md` — checklist da Fase 4 de verificação UI (por completar pelo Cesar).
- `supabase/rls_policies.sql` — SQL Opção D preparado (por aplicar; ver secção RLS).
- `supabase/rls_verificacao.md` — plano de verificação de RLS.
- `supabase/contrato_apps.md` — contrato inter-apps (POS ↔ Control) e discrepância Opção A vs D.
- `../ROADMAP.md` (raiz do repo pai) — aviso bloqueante: sem RLS aplicado, base está aberta.
- Este documento.

### Ronda: painel de controlo remoto (18/07/2026)

Branch `feature/painel-controlo-remoto` (a partir de `master`).

Antes desta ronda, para dar 5 dias a um cliente que ligava, era preciso ir ao
SQL do Supabase. Agora resolve-se em dois cliques no `DetalheClienteScreen` ou
directamente na lista.

- **Edge Function `gerir-licenca`**, com autorização em duas camadas: cliente
  anon + header do caller para `getUser()` e `is_admin()`, e só depois
  service_role para a mutação. `verify_jwt: true` sozinho **não** chegava — a
  anon key também produz JWTs válidos. Verificado: chamada com anon key → 401.
- **Migration aditiva `admins` + `is_admin()`.** Estavam definidas em
  `supabase/rls_policies.sql` mas o ficheiro **nunca tinha sido aplicado** — a
  função não existia na base. Não fecha RLS; isso continua no gate do Cesar.
- **Toda a mutação de licença passa pela function.** `activar()` e
  `actualizar()` do repositório ficaram `@Deprecated` e sem chamadores. Foi
  preciso acrescentar a acção `definir_validade` porque a renovação usa uma
  data escolhida à mão, que `prolongar` (5/15/30) não exprime.
- **Auditoria em `licencas_audit`** — não se criou `audit_licencas`. Cada acção
  produz duas linhas: a do trigger (`acao` nula, `actor_uid` nulo porque
  service_role não tem `auth.uid()`) e a explícita da function, com o autor
  verificado. O modal filtra por `acao is not null`.
- **`tier` vs `plano`:** o chip de plano na UI lê `licencas.tier`.
  `licencas.plano` não se toca — é a duração e entra na assinatura HMAC do
  `licenca.json` do POS.
- **Card de preferências read-only** com a mesma regra do `featureVisivel` do
  POS: num terminal Base tudo aparece desligado, mesmo com o JSONB a `true`.
- **28 testes novos**; suite **101 verde**, analyze limpo.

⚠️ `licencas.tier` tem `default 'base'`, portanto as licenças existentes ficaram
todas Base. Promover o terminal de teste a Pro antes de o exercitar.

### Ronda: correcções da sessão de teste — v1.6.0 (19/07/2026)

Mesmo branch `feature/painel-controlo-remoto`.

- **401 na `gerir-licenca`.** O `supabase_flutter` auto-injecta a anon key no
  `Authorization` do `functions.invoke`: o `verify_jwt: true` passava, mas o
  `getUser()` dentro da função não encontrava utilizador e devolvia 401. O
  cliente passa agora o `accessToken` da sessão explicitamente, e dá erro claro
  ("inicia sessão de novo") quando não há sessão. Auditoria feita: o
  `GerirLicencaService` é o **único** caller de Edge Functions no Control, não
  havia mais nada para corrigir.
- **Nome comercial.** `Licenca` e `Cliente` ganham `nomeComercial`. O destaque
  na UI passa a ser o nome comercial — é por ele que se reconhece a loja — com
  a designação social na linha pequena. Feito no `ContextoInstalacoes.nomeDe`,
  que já alimentava lista, pesquisa e KPIs: uma alteração, todos os ecrãs.
  Cascata: comercial (cliente → licença) → designação (idem) → NIF.
- **Card "Último acesso".** "Sinal" e "Sinal diz" eram duas linhas e pareciam
  dois sinais quando é um só. Fundidas numa: o método passa a ser a etiqueta
  (`GPS: Lisboa`), com o ícone colorido à esquerda. Sem sinal mostra `—` em vez
  de uma cidade órfã. "Quando" passa a dar data absoluta e relativa — "há 2
  dias" sozinho não distingue um fim-de-semana de uma avaria. Mesmo tratamento
  no detalhe de pedido de ajuda.
- **19 testes novos**; suite **120 verde**, analyze limpo.

Nota: a linha "Loja" que o prompt pedia já existia no card.

---

### Ronda: mostrar IP e telefone — v1.6.2 (21/07/2026)

Branch `feature/mostrar-ip-telefone`. Sprint pequeno, par do POS 2.0.6.

- **#95**: o modelo `Ping` passa a ler `ip_publico`, `estado_licenca`,
  `termos_aceites` e `origem` — o POS já os enviava desde a ronda de
  observabilidade, faltava o Control lê-los. No `DetalheClienteScreen`, o card
  "Último acesso" mostra `IP: <endereço>` quando o ping o traz. Os `select()`
  dos pings já eram `*`, portanto não houve alteração de repositório.
- **#96**: os dados do cliente ganham a linha "Telefone", com ícone que abre o
  marcador do sistema (`Acoes.ligarPara`, o helper `tel:` já existente). Só
  aparece quando o cliente tem telemóvel preenchido.
- **6 testes novos**; suite **132 verde**, analyze limpo.

### Ronda: hora local nos timestamps — v1.6.3 (22/07/2026)

Branch `feature/webservice-series-control-v2-1` (patch em cima da ronda das
séries, ainda por fazer merge). Bug apanhado no teste do POS 2.0.6 + APK 1.6.2.

- **#101**: o card "Último acesso" mostrava a hora **1h a menos** (10:56 em vez
  de 11:56) — exactamente o offset UTC↔WEST no verão. Causa: `created_at` é
  `timestamptz` (guardado em UTC) e `DateTime.parse` devolve um DateTime com
  `isUtc = true`; `Dates.data`/`Dates.dataHora` formatavam sem `.toLocal()`.
- **Fix central**: `.toLocal()` dentro de `Dates.data` e `Dates.dataHora`
  ([lib/core/dates.dart](../lib/core/dates.dart)). Como **todos** os widgets de
  timestamp passam por este helper (detalhe do cliente, historial
  `licencas_audit`, pedidos de ajuda, séries, sugestões), a correcção propaga-se
  a todos de uma vez. `.toLocal()` é idempotente — num DateTime já local é no-op.
- **Não tocado**: modelos (`Ping`/`Licenca`/`SerieComunicada` continuam a
  receber UTC via `DateTime.parse`), schema Supabase (timezone continua UTC), e
  os `timeago.format(...)` (relativos — imunes ao bug). Export CSV do backup
  mantém `toIso8601String()` (UTC, correcto para dados).
- **Testes TZ-robustos** em `test/dates_test.dart`: comparam contra a hora local
  calculada em runtime (o runner do CI pode estar em qualquer timezone) e, com
  offset ≠ 0, garantem que a hora UTC crua já não aparece. Suite **verde**,
  analyze limpo (só o aviso pré-existente `anonKey` deprecated em main.dart).

## 7. Roadmap — o que falta

### Curto prazo (esta semana ou próxima)

- **Verificação UI real da ronda 1.4.0** — Cesar corre `docs/verificacao_apk_r1_4.md`
  no telemóvel (APK release da `feature/redesign-visual`). Sem isto o merge fica suspenso.
- **Fechar a Fase 4 de verificação UI do R1** — Cesar corre `docs/verificacao_apk_r1.md` no telemóvel. Sem isto o merge de `feature/melhorias-r1-r2` para `master` fica em suspenso.
- **Merge de `feature/melhorias-r1-r2` para `master`** — depois da Fase 4 fechar.
- ✅ **Trigger DB automático** — entregue e testado em produção (ver ronda `trigger_push_backend` acima).
- **Refinar tap na notificação** — hoje ao carregar numa notificação abre a app em qualquer ecrã; devia abrir directamente na secção "Início de actividade" do Dashboard. Requer `onMessageOpenedApp` handler no `main.dart`.

### Médio prazo (depois do curto, antes da AT)

- ✅ **Redesign visual completo** (Dashboard, Instalações, DetalheCliente, Mapa,
  Sobre, Login) — **entregue na ronda 1.4.0** (branch `feature/redesign-visual`).
  Os 6 problemas conhecidos (machine_id, card inerte, KPIs, AppBar, badge NEW,
  ecrã vazio) foram resolvidos. Markers PNG custom do Mapa **feitos**
  (`assets/markers/`). Falta só: **verificação UI real no telemóvel**.
- ✅ **Design tokens** — entregue (`app_colors`/`app_theme`/`app_spacing`/`app_radius`).
- **Buracos de segurança pendentes**:
  - `company_signature_settings` e `invoice_signature_logs` com RLS desligado — ligar RLS sem policies anon (só service_role via Edge Function pode escrever).
  - Índice único parcial na série activa: `create unique index licencas_serie_activa_unique on licencas (lower(trim(serie))) where activa=true and serie is not null`.
  - Auditoria mínima de `licencas` (tabela `licencas_audit` + trigger).

### Pós-v2.0 certificada — refactor "extrair core fiscal reutilizável"

- Extrair `lib/services/fiscal/`, `lib/services/signing/`, `lib/services/licenca/`, motor SAF-T, ATCUD, hash, webservice AT para um **package Dart separado** (`washinvoice_fiscal_core`, git submodule ou pub privado).
- WashInvoice actual passa a ser o **vertical "Lavandaria"** que depende do core.
- Novos verticais (Restauração, Retalho, outros nichos) construídos sobre o mesmo core — cada um com **binário próprio e número de certificação AT próprio** (a AT certifica binários, não módulos).
- Ganho estratégico: novo vertical = 6-8 semanas (só UI + fluxos), não 6 meses.
- Timing: só depois da v2.0 estar aprovada. Fazer antes é risco desnecessário.
- Higiene a manter nos sprints da v2.0 para o refactor ser leve:
  - Camadas claras (nenhuma referência a UI de lavandaria dentro de código fiscal).
  - Configuração externa via `Config` (nome empresa, séries, contactos, tipos de doc suportados).
  - Testes unitários no motor fiscal, não em UI.

### 5 dias antes de submeter à AT (POS)

- **POS — Dossier certificação AT + estabilização** (`feature/dossier-certificacao-at`): prompt em `D:\WashFactura\docs\design\prompt_pos_dossier_at.md`.
  - Auditoria (`analyze`, `test`), amostras PDF/A validadas veraPDF, SAF-T validado XSD, hash chaining com valores reais, ATCUD e QR descodificados, dossier técnico `docs/certificacao_at/*` com 8 secções, estabilização de warnings, sem features novas.
  - Bump `1.6.6+22` ou `1.6.7+22`. Zip `docs/certificacao_at.zip` pronto para AT.

### Em paralelo à análise AT (branch dedicada, submissão em adenda)

- **POS 2.0 — Guias de Transporte** (`feature/guias-*` no repo POS). Prompts prontos em `D:\WashFactura\docs\guias_transporte\sprints\`:
  - **PoC SSL** (`PoC_ssl_client_cert.md`) — antes do Sprint 6, prova que HTTPS mútuo funciona.
  - **S1** — Modelos + DB (`S1_modelos_db.md`).
  - **S2** — UI emissão GR (`S2_ui_emissao_gr.md`).
  - **S3** — Assinatura + hash chaining + ATCUD (`S3_assinatura_hash_atcud.md`).
  - **S4** — PDF/A da guia (`S4_pdf_a_guia.md`).
  - **S5** — SAF-T MovementOfGoods (`S5_saf_t_movement_of_goods.md`).
  - **S6** — Webservice AT SOAP + WS-Security (`S6_webservice_at.md`).
  - **S7** — Anulação + consulta + segunda via + retry (`S7_anulacao_consulta_2via.md`).
  - **S8** — Dossier adenda AT + release v2.0.0 (`S8_certificacao_v2_release.md`).
  - Estimativa total 8-11 semanas. Justificação: 50% do mercado alvo (lavandarias/engomadorias) faz entregas ao domicílio.
  - **Não atrasa** submissão AT actual — submeter v1.6.x com Facturação no dia 20; adenda com Guias depois.

### Depois da aprovação AT do POS

- **RLS Opção A ou D final** — reconciliar o `rls_policies.sql` preparado com o desenho actual, aplicar. Ver `supabase/contrato_apps.md`.
- **HMAC → Ed25519 na assinatura de licenças** — Edge Function `emitir_licenca` no Supabase com chave privada Ed25519 como secret. POS valida com chave pública embutida no binário. Elimina a maior brecha ("qualquer um que extrai o binário emite licenças").
- **POS a autenticar-se no Supabase** — cada terminal com credenciais próprias, RLS por `auth.uid()` real. Fim do teatro anon-key.
- **Alertas e lembretes internos** — licenças a expirar em N dias, sem contacto recente, licença expirada mas máquina ainda faz ping. Push automático via trigger.
- **Exportação CSV/XLSX** — clientes, licenças, expirações próximas.
- **Sentry ou tabela `app_errors`** — captura persistente de erros em produção.
- **Multi-ambiente** (`--dart-define=SUPABASE_URL=...`) — só quando fizer sentido separar dev/staging/prod. Overkill hoje.

---

## 8. Decisões arquitecturais tomadas

Registo dos "porquês" que não devem ser esquecidos:

- **Não tocar no POS até depois da AT.** Qualquer alteração ao WashFactura abre risco fiscal. Excepções permitidas: mudanças de texto puro no ecrã "Comprar licença" (contactos, sem tocar em lógica fiscal).
- **RLS por `auth.uid()` no POS (Opção D) fica para depois da AT.** Hoje o POS não autentica — usa só anon key. Migrar é mexer no POS → adiado.
- **Chave HMAC no POS é a maior brecha.** Reconhecida. Fica para pós-AT, junto com migração para Ed25519 numa Edge Function.
- **Um único admin (Cesar) por agora.** Push notifications, RLS admin — tudo desenhado para 1 utilizador. Multi-admin fica para quando fizer sentido comercial.
- **Cliente contacta o Cesar por canais fora da app.** IBAN não vai em email da app. Email de acolhimento é sinal de "há venda iminente", sem preço nem instruções de pagamento. IBAN sai do próprio Cesar (WhatsApp/telefone/email pessoal) quando o cliente responder.
- **`Config.urlPagamento` fica vazio.** Landing page de pagamento não existe. Se um dia existir, entra numa linha condicional do email de acolhimento (já preparada, não activa).
- **Edge Function `enviar-push` com `verify_jwt: false` + secret partilhado.** Custom auth via header. `service_role_key` não é distribuído.
- **Google Analytics do Firebase desactivado.** É um utilizador (Cesar), zero valor, tira um wizard step.
- **Plano Firebase Spark (grátis).** FCM é grátis. Não fazer upgrade sem razão explícita.
- **`azul900` = `#1F5F87` (v1.4).** O redesign introduziu este tom como superfície
  da AppBar (texto branco ~6:1, passa WCAG AA). O `tokens.md` foi corrigido para
  não mentir. `azul700` deixa de ser a AppBar; fica para botões primários sobre branco.
- **`ContextoInstalacoes` como fonte única de lookups (v1.4).** Em vez de cada ecrã
  reconstruir mapas machine→licença/cliente/ping e re-decidir nome/sinal/localidade,
  há um índice partilhado. Reduz divergência entre ecrãs (regra "um só sítio").
- **Retenção de pings no servidor (v1.4).** Trigger `limitar_pings_por_maquina`
  (120/máquina) em vez de limpeza no cliente — mais barato e sempre consistente.
  É destrutivo (DELETE a cada insert); aplicado em produção com autorização.
- **Features novas como secções do Dashboard, não abas.** Pedidos de Ajuda e
  Sugestões abrem por `MaterialPageRoute`; o bottom nav mantém-se em 3 tabs.
- **Aviso físico em foreground (v1.4.1).** O SnackBar em foreground é silencioso
  (só a notificação nativa em background tem som). Optou-se por `HapticFeedback`
  (vibração) em vez de adicionar `flutter_local_notifications` — mais simples,
  sem package novo. Se um dia se quiser notificação nativa também em foreground,
  passa a `flutter_local_notifications` (fica para 1.4.2 se o Cesar pedir).
- **Auto-refresh por stream, não polling (v1.4.1).** O Dashboard recarrega por um
  `StreamController` broadcast que o listener de push alimenta. Escolhido em vez
  de polling periódico (gastava rede/bateria) ou de reconstruir o ecrã inteiro.

---

## 9. O que não entra no repo (mas convém saber)

- Chave `washinvoice-control-XXXX.json` — no disco local do Cesar, fora do repo. Se se perder, gerar nova em GCP IAM → adicionar ao Supabase secret. A antiga fica revogada.
- Password do login Supabase — no gestor de passwords do Cesar.
- Firebase / GCP credentials — na conta Google `cesarmendes78@gmail.com` do Cesar.

---

## 10. Como reproduzir do zero (recuperação de desastre)

Se um dia for preciso recriar tudo:

1. `git clone` do repo.
2. `flutter pub get`.
3. Criar novo projecto Firebase (ou reutilizar `washinvoice-control`).
4. Descarregar novo `google-services.json` → `android/app/`.
5. Criar service account nova em GCP IAM com roles "Firebase Cloud Messaging Admin" + "Firebase Admin".
6. Descarregar chave JSON → guardar fora do repo.
7. Meter conteúdo no secret `FCM_SERVICE_ACCOUNT_JSON` do Supabase.
8. Gerar novo `EDGE_INVOKE_SECRET` (`openssl rand -hex 32`) → secret no Supabase.
9. Re-deployar Edge Function `enviar-push` (código em `supabase/functions/enviar-push/index.ts` — **por versionar no repo**, hoje só existe no Supabase). TODO.
10. Aplicar migrations Supabase (`supabase/*.sql` — parcialmente versionados, ver secção RLS).
11. `flutter build apk --release` → instalar → testar push com curl.

**TODO:** versionar Edge Functions no repo (`supabase/functions/enviar-push/index.ts`). Hoje o código só existe no Supabase — se apagar por engano, perde-se.
