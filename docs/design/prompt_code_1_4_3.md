# Prompt para Claude Code — WashInvoice Control 1.4.3

> Cola na sessão do Code aberta em `D:\WashInvoiceControl\washinvoice_control\`.
> Branch: **`feature/1.4.3-melhorias`** a partir de `master` (ou da `feature/1.4.2-conteudo` se ainda não foi merged).
> Alvo: v1.4.3+17.

---

## Contexto

Backend já aplicado por mim via MCP nesta ronda (Cesar autorizou "vais alterar isso tudo"):

1. **Edge Functions versionadas no repo** — `supabase/functions/enviar-push/index.ts` e `supabase/functions/assinar-documento/{index,assinatura}.ts` + `supabase/functions/README.md`. Passa a ser fonte de verdade.
2. **Índice único parcial na série activa** — `licencas_serie_activa_unique` — impede duas licenças activas com a mesma série.
3. **Auditoria de licenças** — tabela `licencas_audit` (bigserial id, licenca_id, operacao, actor_uid, actor_role, antes jsonb, depois jsonb, campos_alterados text[], criado_em) + trigger `trg_audit_licencas` (INSERT/UPDATE/DELETE, filtra updates que não mudaram nada). RLS activo, SELECT authenticated.
4. **RLS ligado em `company_signature_settings` e `invoice_signature_logs`** — antes expostas a anon. Agora SELECT authenticated (admin lê logs), sem INSERT/UPDATE/DELETE para qualquer role (só service_role da futura Edge Function `assinar-pdf` passa).

Este prompt cobre o lado Flutter. Objectivo: dar utilidade ao que ficou preparado + melhorias UX prometidas.

---

## Fase 1 — Inventário (não escrever código)

Confirmar:

1. Que a `feature/1.4.2-conteudo` já foi executada (ou fazer merge / rebase). Se não, arrancar a 1.4.3 já com esses ajustes ou aplicá-los antes de continuar.
2. Existência de `lib/features/sugestoes/sugestoes_screen.dart` e do padrão do `DetalhePedidoAjudaScreen` (da 1.4.2).
3. Existência de `lib/features/instalacoes/instalacoes_screen.dart` com filtros já implementados na 1.4.0.
4. Que os repositórios `licencas_repository.dart` e `pings_repository.dart` estão a devolver dados.
5. Que a nova tabela `licencas_audit` está acessível ao admin (query SELECT deve devolver linhas se houver auditoria já registada — inclui o meu teste `teste_audit_001`).

Reportar. **Não avançar sem confirmação.**

---

## Fase 2 — Alterações Flutter

### 2.1 `DetalheSugestaoScreen` (par natural do detalhe de pedido de ajuda)

Novo ficheiro `lib/features/sugestoes/detalhe_sugestao_screen.dart`. Estrutura análoga ao `DetalhePedidoAjudaScreen` mas para sugestões:

- **AppBar** azul-900 com chevron voltar + título `nomeDe(...)` do cliente/NIF + chip:
  - `Por ler` (roxo) se `lida = false`
  - `Marcada` (laranja com estrela) se `marcada = true` (pode coexistir com estados)
  - `Arquivada` (cinza) se `arquivada = true`
- **Card "Sugestão"** (`WiCard`, ícone `lightbulb_outline` roxo):
  - Texto integral seleccionável (`SelectableText`), sem truncar.
  - "Enviada em: {timeago} · {data completa}".
- **Card "Cliente/Terminal"** (idêntico ao do DetalhePedidoAjuda):
  - Nome, NIF, localidade, machine_id monospace + copiar, estado da licença.
- **Botões de acção** (empilhados):
  - `Marcar como importante` / `Desmarcar` (toggle da estrela laranja).
  - `Arquivar` (se ainda não arquivada, verde outlined). Se já arquivada, esconder.
  - `Ver ficha completa do cliente` (TextButton azul → `DetalheClienteScreen(machineId: sugestao.machineId)`).

Ao navegar a partir de `SugestoesScreen`, tap num card abre este ecrã. Depois de fechar, `_recarregar()` para reflectir mudanças.

### 2.2 Ordenação nas Instalações

Em `lib/features/instalacoes/instalacoes_screen.dart`, ao lado dos filtros existentes, adicionar dropdown de ordenação:

- **Rótulo**: "Ordenar por"
- **Opções**:
  - `Último acesso` (default — mais recente primeiro)
  - `Nome do cliente` (A→Z)
  - `Validade` (mais próximo do fim primeiro)
  - `Localidade` (A→Z)
- Aplicar client-side sobre a lista já filtrada. Guardar preferência em `SharedPreferences` (`instalacoes_ordenacao`) para persistir entre sessões.

### 2.3 Pesquisa global

Novo ecrã `lib/features/pesquisa/pesquisa_global_screen.dart` acessível por ícone `search` na AppBar do Dashboard (ao lado do refresh e info).

- **Campo** de pesquisa no topo (foco automático ao abrir).
- Ao escrever ≥2 chars, procurar em paralelo em:
  - `clientes` (nome, nif, email, telemovel, notas, localidade)
  - `licencas` (nif, nome, machine_id, serie)
  - `pings` (nif, machine_id, cidade)
  - `pedidos_ajuda` (nif, machine_id, notas)
  - `sugestoes` (nif, machine_id, texto)
- Resultados agrupados por categoria com contagem: `Clientes (3)`, `Licenças (1)`, `Pedidos de ajuda (0)`, etc.
- Cada resultado é um card compacto navegável (tap → ecrã apropriado — DetalheCliente, DetalhePedido, DetalheSugestao).
- Debounce 250ms para não fazer 5 queries por cada tecla.
- Estado vazio: "Escreve para procurar em toda a tua base."
- Sem resultados: "Nada encontrado para «X»."

### 2.4 Exportação CSV (backup)

Novo ecrã `lib/features/backup/backup_screen.dart` acessível de Sobre/Sistema → botão "Exportar dados".

- **Botões grandes** empilhados:
  - `Exportar clientes` — CSV de `clientes` (todos os campos).
  - `Exportar licenças` — CSV de `licencas`.
  - `Exportar pedidos de ajuda` — CSV com abertos + histórico (colunas: id, machine_id, nif, cliente, criado_em, resolvido_em, duracao, notas).
  - `Exportar sugestões` — CSV.
  - `Exportar tudo (ZIP)` — usa `archive` package para juntar os 4 CSVs num zip.
- Cada botão gera o ficheiro em memória e chama `share_plus` (`Share.shareXFiles([XFile.fromData(bytes, name: 'clientes.csv')])`) — Cesar escolhe onde guardar (Google Drive, WhatsApp para si próprio, etc.).
- Localidade dos ficheiros CSV: usa `Localidades.traduzir()` para as cidades (mesmo helper do 1.4.2).
- Encoding UTF-8 com BOM (para Excel abrir bem).

### 2.5 (opcional) Chip da série em `WiBadgeEstado` ou noutro sítio se detectar duplicado

Se o código actual permitir emitir duas licenças com a mesma série activa via UI (sem erro Postgres), o novo índice único vai lançar violação. Adicionar tratamento no `emitir_licenca` do Control para mostrar mensagem clara em vez de excepção crua: "Já existe uma licença activa com a série «X»."

Verificar `licencas_repository.dart::criar()` e `licenca_emissao.dart` (se existir).

---

## Fase 3 — Testes

- `test/detalhe_sugestao_test.dart` — widget test navegação + acções (marcar, arquivar).
- `test/instalacoes_ordenacao_test.dart` — ordenar 4 items por cada critério, verificar ordem.
- `test/pesquisa_global_test.dart` — mock repositórios, escrever "abc" → debouncing, resultados agrupados.
- `test/backup_test.dart` — gerar CSV de dados mock, verificar UTF-8 BOM + escape de vírgulas/aspas.

`flutter test` verde. `flutter analyze` limpo.

---

## Fase 4 — Verificação UI real

Compila release APK, instala. Regista em `docs/verificacao_apk_r1_4_3.md`:

1. **Sugestão** — abrir uma sugestão do arquivo (ou criar teste) → aparece `DetalheSugestao` com texto completo. Marcar como importante → estrela troca. Arquivar → sai da lista "Por ler".
2. **Instalações** — dropdown "Ordenar por" tem 4 opções. Trocar entre elas → lista reordena. Fechar e reabrir a app → ordenação escolhida persiste.
3. **Pesquisa global** — tocar no ícone lupa no Dashboard → ecrã abre. Escrever "8a0" → aparecem resultados nas categorias apropriadas. Tap num → abre o ecrã correcto.
4. **Backup** — Sobre/Sistema → "Exportar dados". Cada botão gera ficheiro e abre picker de partilha. Guardar em Google Drive/Downloads. Abrir CSV no Excel → cidades em português, colunas OK, caracteres com acentos correctos.
5. **Duplicado de série** — tentar emitir duas licenças activas com a mesma série (via UI) → mensagem clara, não erro cru.
6. **Sem regressões** dos 1.4.1 e 1.4.2 anteriores.

---

## Fase 5 — Reconciliação da documentação

No fim:

1. Adiciona ronda 1.4.3 ao `estado_e_roadmap.md` na secção "O que foi entregue" — mencionando o backend que eu já apliquei + o Flutter que fizeste.
2. Actualiza a lista de tabelas Supabase — acrescentar `licencas_audit`.
3. Actualiza a lista de Edge Functions — mencionar que estão versionadas em `supabase/functions/`.
4. Se algum item deste prompt não foi implementado como descrito, secção "Reconciliação" no fim deste ficheiro a explicar porquê.

**Regra dourada**: documentação nunca pode mentir sobre o código.

---

## NÃO TOCAR EM

- Backend Supabase (tabelas, policies, triggers) — já aplicado por mim, não redeployar via CLI.
- Edge Functions no Supabase — só se descobrires bug; senão manter iguais aos ficheiros versionados.
- Nada do POS.
- `licenca_assinatura.dart` — HMAC continua até pós-AT.
- FCM Service, background handler.
- Fix da 1.4.1 (`IntrinsicHeight` no `_KpiRow`) — não regredir.

---

## Regras

- Português europeu.
- Widgets `Wi*` são os tijolos reutilizáveis — não introduzir componentes novos ad-hoc para o que já existe.
- Ordenação/pesquisa/backup podem ser client-side (dados pequenos) — só migrar para RPC/server se a base crescer muito.
- Localidades sempre pela `Localidades.traduzir()` (do 1.4.2).

---

## Ordem de commits sugerida

1. `sugestoes: DetalheSugestaoScreen + navegação`
2. `instalacoes: dropdown de ordenação + persistência`
3. `pesquisa: ecrã de pesquisa global cross-entity`
4. `backup: exportação CSV com share_plus`
5. `licencas: mensagem clara quando série activa duplica`
6. `test: sugestao + ordenacao + pesquisa + backup`
7. `version: bump 1.4.3+17`
8. `docs: reconciliação + verificacao`

Não faças merge para `master` sem OK do Cesar.

---

## Reconciliação — o que ficou vs planeado (após implementação)

> Auditoria honesta (Fase 5). Branch: `feature/1.4.3-melhorias` (a partir de
> `feature/1.4.2-conteudo`, já que 1.4.1/1.4.2 não estão merged).

### Contexto de arranque
- A **1.4.2 não existia no repo** quando este prompt chegou (o Cesar mandou "faz
  esta [1.4.2] e depois a seguinte [1.4.3]"). A 1.4.2 foi implementada primeiro;
  por isso `DetalhePedidoAjudaScreen`, `Localidades` e `nomeDe` sem hash já
  existiam ao arrancar a 1.4.3.
- Backend confirmado por inventário (MCP): `licencas_audit` (3 linhas de teste),
  índice `licencas_serie_activa_unique`, RLS ligado nas duas tabelas de assinatura.

### Implementado como descrito → OK
- 2.1 `DetalheSugestaoScreen` (chips, texto integral, cliente/terminal, marcar/
  arquivar, ver ficha) + navegação da lista.
- 2.2 Ordenação nas Instalações + persistência (SharedPreferences).
- 2.3 Pesquisa global (5 fontes, agrupada, debounce).
- 2.4 Backup CSV + ZIP.
- 2.5 Mensagem clara na série duplicada.
- Fase 3 testes (71 verdes), Fase 4 checklist.

### Adaptações (e porquê)
- **`WiCardTitulo`** criado (ícone + título h2) para os cabeçalhos de card dos
  ecrãs de detalhe, em vez de repetir o `_Header` privado. Usado no
  DetalheSugestao (os outros ficam para unificar quando se tocar neles).
- **Backup partilha ficheiro temporário** (`getTemporaryDirectory` + `XFile(path)`)
  em vez de `XFile.fromData` — mais fiável no Android para preservar o nome do
  ficheiro (mesmo padrão da geração do `licenca.json`).
- **`Localidades.traduzir` no CSV**: nenhum dos 4 CSV carrega a `pings.cidade`
  crua (o CSV de clientes usa `clientes.localidade`, que já é PT humano). Por isso
  a tradução não foi necessária nas exportações; continua aplicada onde a cidade
  do ping aparece (pesquisa, cards). Sem tradução redundante.
- **Série duplicada tratada centralmente** em `descreverErro` (case 23505), não
  num try/catch por ecrã — cobre qualquer caminho de emissão. A mensagem é clara
  mas **não inclui o valor «X» da série** (extraí-lo do erro Postgres é frágil).
- **`ordenarInstalacoes`** extraída para função pura (top-level) para ser testável
  sem widget.

### Não tocado ("NÃO TOCAR EM")
Backend Supabase, Edge Functions, POS, `licenca_assinatura`, FCM, e o
`IntrinsicHeight` do `_KpiRow` (fix da 1.4.1) — sem regressões.
