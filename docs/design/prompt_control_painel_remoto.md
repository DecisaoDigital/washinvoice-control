# Prompt Code Control — painel de controlo remoto de licença

> Cola numa sessão nova do Claude Code aberta em `D:\WashInvoiceControl\washinvoice_control\`.
> Branch: **`feature/painel-controlo-remoto`** a partir de master.
> Alvo: controlo remoto sobre licenças a partir do Control — prolongar, suspender, reactivar, cancelar, alternar Base/Pro, ver preferências read-only, historial auditado.

---

## Contexto

Trabalho paralelo com `D:\WashFactura\docs\design\prompt_pos_observabilidade_e_controlo.md` (POS). As migrations Supabase (`licencas.preferencias_features` JSONB, `licencas.plano` domain hint, `pings` enriquecido) são aplicadas pelo prompt do POS — este consome.

Hoje o Cesar não pode fazer nada operacional a partir do Control. Se cliente pede +5 dias, tem de ir directo ao SQL. Este sprint muda isso: botões no `DetalheClienteScreen` que fazem tudo em 2 cliques, com auditoria.

## Autorizações já dadas (não pedir de novo)

- **Migration `audit_licencas`** — aditiva (CREATE TABLE, zero risco para clientes existentes). **Aplica via MCP directamente. Não pedir OK.**
- **Deploy Edge Function `gerir-licenca`** — nova function, isolada, não afecta as existentes. **Deploy via MCP directamente. Não pedir OK.**
- Todas as decisões de design (endpoint, body, comportamento das acções, layout, textos, cores, guardas) estão fechadas neste prompt. **Não pedir confirmação sobre nada que esteja aqui.**

## Único gate

- **Antes do merge:** Cesar faz teste manual (Fase 5). Reportas SHAs, aguardas OK dele, mereges.

## Restrições duras (não negociáveis)

- **NÃO fechar RLS** de `licencas` (esse é gate manual do Cesar noutro prompt).
- **NÃO escrever em `licencas` com anon key.** Toda mutação passa por `gerir-licenca` (service_role).
- **NÃO alterar** máquina de estados de licença.
- **NÃO alterar auth**.
- **NÃO alterar preferências individuais de features** — o Control só mostra read-only.

---

## Fase 1 — Edge Function `gerir-licenca` + migration `audit_licencas`

### 1.1 — Migration `audit_licencas`

Aplica via MCP:

```sql
create table if not exists audit_licencas (
  id uuid primary key default gen_random_uuid(),
  machine_id text not null,
  acao text not null,
  parametros jsonb,
  feito_por text not null,
  licenca_antes jsonb not null,
  licenca_depois jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_audit_licencas_machine_id
  on audit_licencas(machine_id, created_at desc);
```

### 1.2 — Edge Function `gerir-licenca`

Novo `supabase/functions/gerir-licenca/index.ts`. Corre com service_role. Exige `Authorization: Bearer <JWT>` — valida com `supabase.auth.getUser(jwt)`.

Endpoint: `POST /functions/v1/gerir-licenca`

Body:
```json
{
  "acao": "prolongar" | "suspender" | "reactivar" | "cancelar" | "mudar_plano",
  "machine_id": "<hash>",
  "parametros": { ... }
}
```

Comportamento das acções:

| Acção | Parâmetros | SQL efectivo |
|---|---|---|
| `prolongar` | `{ "dias": int }` | `update licencas set validade = greatest(validade, current_date) + interval '<dias> days' where machine_id = ?` |
| `suspender` | `{}` | `update licencas set activa = false where machine_id = ?` |
| `reactivar` | `{}` | `update licencas set activa = true where machine_id = ?` |
| `cancelar` | `{}` | `update licencas set activa = false, validade = current_date where machine_id = ?` — não apaga linha |
| `mudar_plano` | `{ "plano": "base" \| "pro" }` | `update licencas set plano = ? where machine_id = ?` — **não** limpa `preferencias_features` |

Sequência interna:
1. Extrair JWT, `getUser()`. Se falha → 401.
2. Ler linha actual de `licencas` (por `machine_id`). Se não existe → 404 `{ erro: 'terminal desconhecido' }`.
3. Guardar snapshot `licenca_antes`.
4. Executar update.
5. Ler linha nova (`licenca_depois`).
6. Insert em `audit_licencas` com `{ machine_id, acao, parametros, feito_por: user.email, licenca_antes, licenca_depois }`.
7. Devolver 200 com `licenca_actualizada`.

Response:
```json
{
  "ok": true,
  "acao": "prolongar",
  "machine_id": "<hash>",
  "licenca_actualizada": { "activa": true, "validade": "...", "plano": "pro", "preferencias_features": {...} }
}
```

Erros: 401 sem auth, 400 acção/params inválidos, 404 machine desconhecido, 500 DB.

Deploy via MCP. Criar `supabase/functions/gerir-licenca/README.md` com curl exemplo para cada acção.

---

## Fase 2 — `GerirLicencaService` no cliente Flutter

Novo `lib/services/licenca/gerir_licenca_service.dart`:

```dart
class GerirLicencaService {
  final SupabaseClient _supabase;
  GerirLicencaService(this._supabase);

  Future<LicencaAtualizada> prolongar(String machineId, int dias) =>
      _invocar('prolongar', machineId, {'dias': dias});
  Future<LicencaAtualizada> suspender(String machineId) =>
      _invocar('suspender', machineId, {});
  Future<LicencaAtualizada> reactivar(String machineId) =>
      _invocar('reactivar', machineId, {});
  Future<LicencaAtualizada> cancelar(String machineId) =>
      _invocar('cancelar', machineId, {});
  Future<LicencaAtualizada> mudarPlano(String machineId, String plano) =>
      _invocar('mudar_plano', machineId, {'plano': plano});

  Future<LicencaAtualizada> _invocar(String acao, String machineId, Map params) async {
    final r = await _supabase.functions.invoke(
      'gerir-licenca',
      body: {'acao': acao, 'machine_id': machineId, 'parametros': params},
    );
    if (r.data['ok'] != true) throw GerirLicencaException(r.data['erro'] ?? 'falha');
    return LicencaAtualizada.fromJson(r.data['licenca_actualizada']);
  }
}

class LicencaAtualizada {
  final bool activa;
  final DateTime validade;
  final String plano;
  final Map<String, dynamic> preferenciasFeatures;
  const LicencaAtualizada({
    required this.activa,
    required this.validade,
    required this.plano,
    required this.preferenciasFeatures,
  });
  factory LicencaAtualizada.fromJson(Map<String, dynamic> json) => LicencaAtualizada(
    activa: json['activa'] as bool,
    validade: DateTime.parse(json['validade'] as String),
    plano: json['plano'] as String,
    preferenciasFeatures: (json['preferencias_features'] as Map).cast<String, dynamic>(),
  );
}

class GerirLicencaException implements Exception {
  final String mensagem;
  GerirLicencaException(this.mensagem);
}
```

---

## Fase 3 — UI: cards no `DetalheClienteScreen`

Adicionar duas novas secções abaixo dos dados actuais.

### 3.1 — Card "Controlo remoto"

**Cabeçalho:** título "Controlo remoto" + ícone escudo.

**Grupo 1 — Validade & estado:**
Row de botões:
- `+5 dias` — outlined, cor primária
- `+15 dias` — outlined, cor primária
- `+30 dias` — outlined, cor primária
- `Suspender` — outlined, cor `theme.colorScheme.error` — só aparece se `licenca.activa == true`
- `Reactivar` — outlined, cor `theme.colorScheme.tertiary` (verde) — só aparece se `licenca.activa == false`
- `Cancelar` — TextButton pequeno, cor destrutiva, no fim do card

**Grupo 2 — Plano:**
- `Chip` mostra plano actual: `Base` fundo cinza, `Pro` fundo dourado (`#F5D142`), `Legado` outlined.
- Botão à direita: `Mudar para Pro` (se plano actual = Base) ou `Mudar para Base` (se Pro/Legado).

**Fluxo de cada acção:**
1. `AlertDialog` com resumo:
   - `+5 dias` → *"Prolongar validade em 5 dias. Nova validade: [validade_actual + 5]. Confirmar?"*
   - `Suspender` → *"Suspender licença deste terminal. O POS bloqueia em ≤5 min. Confirmar?"*
   - `Reactivar` → *"Reactivar licença. O POS destranca em ≤5 min. Confirmar?"*
   - `Cancelar` → *"Cancelar licença: termina imediatamente. Não apaga historial. Tens a certeza?"* (dialog com texto ainda mais destacado)
   - `Mudar para Pro` → *"Mudar plano para Pro. Todas as features passam a estar disponíveis. Confirmar?"*
   - `Mudar para Base` → *"Mudar plano para Base. Features Pro deixam de estar activas. Confirmar?"*
2. Loading spinner na área do card.
3. Chama `GerirLicencaService.<acao>()`.
4. Sucesso → `SnackBar` verde: *"[Acção] concluída. POS actualiza em ≤5 min."*
5. Falha → `SnackBar` vermelho: *"Erro: [mensagem]. Tenta novamente."*
6. Refresh do ecrã (invalida provider da licença).

### 3.2 — Card "Preferências do admin" (read-only)

**Cabeçalho:** título "Preferências do admin" + ícone tuning.

Lista de 3 linhas, uma por feature:
- Ícone à esquerda: `Icons.local_shipping` (guias), `Icons.dashboard` (gestao), `Icons.bar_chart` (graficos).
- Nome + descrição curta.
- À direita: ícone check verde se `preferencias.<feature> == true`, ícone off cinza se `false` ou ausente. Nunca toggle interactivo.

Rodapé pequeno em cinza:
> *"As preferências são controladas pelo admin no POS. Se o cliente pedir para mudar, ajuda-o a encontrar o ecrã de Preferências no menu de administração dele."*

### 3.3 — Botão "Ver historial"

Botão TextButton no fim do card de Controlo remoto: *"Ver historial de acções"*.

Ao carregar → `showModalBottomSheet` com lista das últimas 20 entradas de `audit_licencas` para este `machine_id`, `order by created_at desc`.

Cada item:
- Linha 1: `[dd/MM HH:mm] [Acção humanizada]` — ex.: "24/07 15:12 Prolongou +5 dias"
- Linha 2 (cinza pequeno): `por [feito_por]`
- Linha 3 (cinza pequeno, opcional): diff resumido — ex.: "Validade: 2026-08-16 → 2026-08-21"

Botão "Fechar" no topo do bottom sheet.

---

## Fase 4 — Shortcuts em `InstalacoesScreen`

Nas cards da lista, botão `⋯` (`Icons.more_vert`) na direita → abre `showModalBottomSheet` com:
- **+5 dias**
- **Suspender** (se activa) ou **Reactivar** (se suspensa)
- **Ver detalhes** → navega para `DetalheClienteScreen`

Cada opção faz a acção correspondente (mesmo fluxo do card no detalhe), fecha o sheet, refresca lista.

---

## Fase 5 — Testes

### Unitários
- `test/services/licenca/gerir_licenca_service_test.dart` — mock `SupabaseClient`; verificar body correcto para cada acção; parse `LicencaAtualizada`; erro devolve excepção.

### Widget
- `test/features/detalhe_cliente/controlo_remoto_widget_test.dart` — cada botão dispara acção correcta; dialog de confirmação aparece antes de acção; SnackBar de sucesso aparece.
- `test/features/detalhe_cliente/preferencias_readonly_widget_test.dart` — 3 features renderizadas com estado correcto (check/off).
- `test/features/detalhe_cliente/historial_bottom_sheet_test.dart` — bottom sheet abre e mostra entries mockados.
- `test/features/instalacoes/shortcuts_test.dart` — botão `⋯` abre sheet com 3 opções.

`flutter test` verde. `flutter analyze` sem novos avisos.

---

## Fase 6 — Teste manual (Cesar) — ÚNICO GATE

Assume que EXE do prompt paralelo (POS) já está instalado num PC de teste.

1. Abrir Control → `DetalheClienteScreen` do PC de teste.
2. Confirmar que vê versão 2.0.x actualizada, cidade, plano.
3. Carregar `+5 dias` → confirmar dialog → sucesso.
4. Ir à Supabase, verificar que `licencas.validade` avançou 5 dias. Verificar que `audit_licencas` tem entry nova com `feito_por = cesarmendes78@gmail.com`.
5. Voltar ao POS → esperar ≤5 min → confirmar nova validade no ecrã de licença.
6. `Suspender` → voltar ao POS → em ≤5 min mostra "Licença suspensa".
7. `Reactivar` → voltar ao POS → em ≤5 min destranca.
8. `Mudar para Base` → voltar ao POS → menu admin/preferências → carregar em Guias → dialog upsell.
9. `Mudar para Pro` → voltar ao POS → Guias liga sem dialog.
10. Abrir "Historial" → confirmar que todas as acções aparecem com timestamp + user.

Se todos passam, Cesar dá OK no chat, mereges para master.

---

## Fase 7 — Reconciliação

1. Actualizar `docs/estado_e_roadmap.md` do Control.
2. `supabase/functions/gerir-licenca/README.md` com curl por acção.
3. Reportar: SHAs de código, migration ID de `audit_licencas`, confirmação de deploy da function.
4. Task #69 fecha.

---

## NÃO TOCAR EM

- Máquina de estados de licença (é do POS).
- Auth do Control.
- Notificações push.
- Preferências individuais de features (só read-only).

---

## Regras

- Português europeu em todos os textos.
- Cada acção destrutiva (`Suspender`, `Cancelar`, `Mudar para Base`) exige dialog de confirmação com texto claro.
- Se algo é do POS, out-of-scope. Reporta e continua.

---

## Commits sugeridos

1. `licenca: migration audit_licencas`
2. `licenca: Edge Function gerir-licenca + README`
3. `licenca: GerirLicencaService no cliente`
4. `detalhe_cliente: card controlo remoto`
5. `detalhe_cliente: card preferências read-only`
6. `detalhe_cliente: bottom sheet historial`
7. `instalacoes: shortcuts na card`
8. `test: cobertura + widget`
9. `docs: reconciliação`

Reporta SHAs no final. Aguarda OK do Cesar após teste manual (Fase 6) para merge.
