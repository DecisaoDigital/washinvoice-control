# Prompt Code Control — sprint: multi-app (POS + Fist) + badge PRO

> Cola numa sessão nova do Claude Code em `D:\WashInvoiceControl\washinvoice_control\`.
> Branch: **`feature/multi-app-e-badge-pro`** a partir de `main`.
> Alvo: adicionar suporte multi-app ao Control (era só WashInvoice POS, passa a mostrar também Fist) + badge PRO azul antes do nome do cliente. Bump `pubspec.yaml` para próxima versão minor (ex: `1.5.0`).

---

## Contexto

- **Control** é Flutter mobile (Android + iOS). App backoffice da **Decisão Digital** — não é backoffice apenas do WashInvoice, é o controlador de **todas** as apps da empresa.
- **Supabase:** projecto `oefqbkhioncakojipqyx`. Cowork já aplicou migration multi-app hoje:
  - Coluna `app text NOT NULL` (CHECK `pos|punho`) em: `licencas`, `pings`, `pedidos_renovacao`, `pedidos_ajuda`, `sugestoes`, `aceites_termos`.
  - Rows existentes migraram para `'pos'`.
  - EFs `registar-terminal` v6 e `validar-licenca` v6 exigem `body.app` obrigatório.
- **Push notifications** (via FCM): já existentes para POS. Trigger DB grava novo terminal → EF `enviar-push` chama Firebase. A tabela de dispositivos admin já existe (`admin_dispositivos`).
- **Fica também nesta sprint:** task **#177** — badge "PRO" antes do nome do cliente. Cor azul VSCode `~#007ACC`, letras mais reduzidas que o nome.

---

## Autorizações

- Editar todos os repositories que fazem query a: `licencas`, `pings`, `pedidos_renovacao`, `pedidos_ajuda`, `sugestoes`, `aceites_termos`. Adicionar filtro por `app` conforme selector.
- Adicionar provider Riverpod global `appFilterProvider` (state: `'todas' | 'pos' | 'punho'`, persistente em SharedPreferences).
- Novos widgets: `AppSelector` (dropdown no dashboard), `AppBadge` (badge por linha), `TierBadge` (badge PRO).
- Actualizar EF `enviar-push` — o Cowork trata desta parte no Supabase se necessário, o Control não precisa alterar. Se o payload do push mudar (novo campo `app`), o handler client-side é ajustado.
- Bump `pubspec.yaml` conforme padrão do projecto (ex: `1.4.x` → `1.5.0`).

---

## Fase 1 — App filter provider

### 1a. `lib/core/app_filter/app_filter_provider.dart` (novo)

```dart
enum AppFiltro { todas, pos, punho }

extension AppFiltroExt on AppFiltro {
  String get etiqueta => switch (this) {
    AppFiltro.todas => 'Todas as apps',
    AppFiltro.pos   => 'WashInvoice',
    AppFiltro.punho => 'Fist',
  };

  /// Devolve o valor a passar ao filtro SQL `.eq('app', ...)`, ou null se todas.
  String? get valorApp => switch (this) {
    AppFiltro.todas => null,
    AppFiltro.pos   => 'pos',
    AppFiltro.punho => 'punho',
  };
}

class AppFilterNotifier extends StateNotifier<AppFiltro> {
  AppFilterNotifier() : super(AppFiltro.todas) { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_filtro') ?? 'todas';
    state = AppFiltro.values.firstWhere((f) => f.name == saved, orElse: () => AppFiltro.todas);
  }

  Future<void> definir(AppFiltro f) async {
    state = f;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_filtro', f.name);
  }
}

final appFilterProvider = StateNotifierProvider<AppFilterNotifier, AppFiltro>(
  (ref) => AppFilterNotifier(),
);
```

### 1b. Testes

- `test/core/app_filter/app_filter_provider_test.dart` — verificar persistência em SharedPreferences (usa `setMockInitialValues`).

---

## Fase 2 — Repositories: aplicar filtro por app

Cada repository que faz query a tabelas com coluna `app` deve aceitar filtro opcional e aplicar.

### 2a. `lib/repositories/licencas_repository.dart`

Adicionar parâmetro opcional `app` em cada método de leitura. Exemplo:

```dart
Future<List<Licenca>> listar({String? app}) async {
  var q = _client.from('licencas').select();
  if (app != null) q = q.eq('app', app);
  final rows = await q;
  return rows.map((r) => Licenca.fromJson(r)).toList();
}
```

Fazer o mesmo em `listarPorNif`, `listarPendentesRevisao`, etc.

**Regra INSERT/UPDATE:** cada `.insert({...})` para `licencas` **tem de** incluir `'app': 'pos'` (o Control só cria licenças manuais para POS por agora — Fist auto-onboarda; se um dia Cesar criar linha manual para Fist no Control, aí passa `'app': 'punho'`).

### 2b. Outros repositories

Aplicar o mesmo padrão em:
- `lib/repositories/pings_repository.dart` (ou similar)
- `lib/repositories/pedidos_ajuda_repository.dart`
- `lib/repositories/sugestoes_repository.dart`
- `lib/repositories/pedidos_renovacao_repository.dart`

Grep para descobrir:
```bash
grep -rn "from('licencas')\|from('pings')\|from('pedidos\|from('sugestoes')\|from('aceites_termos')" lib/
```

### 2c. Providers de dados usam `appFilterProvider`

Exemplo em `dashboard_provider.dart`:

```dart
final instalacoesProvider = FutureProvider<List<Licenca>>((ref) {
  final filtro = ref.watch(appFilterProvider);
  return ref.read(licencasRepositoryProvider).listar(app: filtro.valorApp);
});
```

`ref.watch` garante que quando o filtro muda, a lista re-carrega.

---

## Fase 3 — Widgets visuais

### 3a. `lib/shared/widgets/app_selector.dart` (novo)

Dropdown no dashboard, canto superior direito da AppBar ou logo abaixo:

```dart
class AppSelector extends ConsumerWidget {
  const AppSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(appFilterProvider);
    return DropdownButton<AppFiltro>(
      value: filtro,
      onChanged: (f) {
        if (f != null) ref.read(appFilterProvider.notifier).definir(f);
      },
      items: AppFiltro.values.map((f) => DropdownMenuItem(
        value: f,
        child: Row(
          children: [
            _iconePorApp(f),
            const SizedBox(width: 8),
            Text(f.etiqueta),
          ],
        ),
      )).toList(),
    );
  }

  Widget _iconePorApp(AppFiltro f) => switch (f) {
    AppFiltro.todas => const Icon(Icons.apps),
    AppFiltro.pos   => const Icon(Icons.point_of_sale, color: Color(0xFF007ACC)),
    AppFiltro.punho => const Icon(Icons.pan_tool, color: Colors.green),
  };
}
```

### 3b. `lib/shared/widgets/app_badge.dart` (novo)

Badge pequeno para colocar por linha na lista de instalações:

```dart
class AppBadge extends StatelessWidget {
  final String app; // 'pos' | 'punho'
  const AppBadge({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (app) {
      'pos'   => (const Color(0xFF007ACC), 'POS'),
      'punho' => (Colors.green.shade700, 'FIST'),
      _       => (Colors.grey, app.toUpperCase()),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
```

### 3c. `lib/shared/widgets/tier_badge.dart` (novo — #177)

Badge PRO antes do nome do cliente. Só aparece se `tier == 'pro'`:

```dart
class TierBadge extends StatelessWidget {
  final String? tier; // 'base' | 'pro' | null
  const TierBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    if (tier != 'pro') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF007ACC).withOpacity(0.15),
        border: Border.all(color: const Color(0xFF007ACC), width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Color(0xFF007ACC),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
```

Uso: `Row(children: [TierBadge(tier: licenca.tier), Text(licenca.nome ?? '—')])`.

---

## Fase 4 — Aplicar widgets nos ecrãs

### 4a. Dashboard (`lib/features/dashboard/`)

- Adicionar `AppSelector` na AppBar (após título, antes de outros ícones).
- KPIs/cards do dashboard passam a mostrar contagens filtradas por app.
- Se filtro = `todas`, mostrar breakdown por app ("POS: N | Fist: M").

### 4b. Lista de instalações (`lib/features/instalacoes/`)

- Cada linha ganha `AppBadge` no início (antes do nome/NIF).
- `TierBadge` antes do nome quando aplicável.
- Filtro por app já aplicado via `appFilterProvider`.

### 4c. Ficha do cliente (`lib/features/instalacoes/detalhe_cliente_screen.dart` ou similar)

- No cabeçalho, ao lado do nome do cliente: `TierBadge` (esquerda) + nome + `AppBadge` (direita).

### 4d. Ecrãs de pedidos de ajuda / sugestões

- Cada pedido lista `AppBadge` (para admin saber de que app veio o pedido).
- Filtro por app aplicado.

### 4e. Testes

- Widget tests para os 3 badges (isolados).
- Widget test do dashboard com filtro (mudar filtro → lista muda).
- Widget test ficha cliente com `tier='pro'` → badge PRO renderiza; com `tier='base'` → não renderiza.

---

## Fase 5 — Push notifications distintas por app

O trigger DB `push_novo_terminal` (task #98) hoje envia mensagem "Novo terminal". Precisa distinguir app.

**Cowork trata desta parte no Supabase.** O Control apenas precisa de:

- Handler FCM no client-side (Flutter) que interpreta o payload novo — se vier campo `app`, mostrar prefixo no notification (`[POS] Novo terminal ABC` ou `[PUNHO] Novo terminal XYZ`).
- Verificar em `lib/services/push/` (ou onde estiver) — deve haver um `_onMessage(RemoteMessage)`. Extrair `message.data['app']` se existe e injectar no título/corpo.

Se este handler ainda não existe, criar; se existe, adicionar 2-3 linhas para prefixo.

### 5a. Testes

- `test/services/push/handler_test.dart` — payload com `app: 'punho'` → título contém `[PUNHO]`; sem `app` → título default (retro-compat).

---

## Fase 6 — Documentação

### 6a. `docs/estado_e_roadmap.md`

Adicionar secção "Multi-app support" no topo:

```markdown
## Multi-app support (adicionado 25/07/2026)

O Control passou a suportar múltiplas apps da Decisão Digital. Coluna `app`
nas tabelas de licenciamento (`licencas`, `pings`, `pedidos_ajuda`, etc.) é
NOT NULL sem default — cliente tem de passar explícito.

Selector no dashboard: Todas | WashInvoice | Fist. Filtro persistente em
SharedPreferences. Badges `POS` (azul) e `FIST` (verde) por linha.

Badge PRO (azul VSCode #007ACC) antes do nome do cliente quando
`licenca.tier == 'pro'`.

Push notifications distinguem app no título ([POS] vs [PUNHO]).

Próximas apps a integrar: — (nenhuma prevista curto prazo).
```

### 6b. Novo `docs/design/multi_app.md`

Documentar arquitectura das decisões (coluna `app` vs tabelas separadas — por
que se escolheu coluna).

---

## Fase 7 — Verificação (obrigatória antes de PR)

1. `flutter pub get`
2. `flutter test` — todos verdes
3. `flutter analyze` — limpo
4. Testar app localmente:
   - Filtro "Todas" → vê linhas com badge POS e FIST
   - Filtro "WashInvoice" → só POS
   - Filtro "Fist" → só Fist
   - Cliente com `tier='pro'` no BD → badge PRO renderiza na ficha
   - Cliente com `tier='base'` → sem badge
5. Push notification simulada com `app='punho'` no payload → título "[PUNHO] …"
6. Bump `pubspec.yaml` (ex: `1.4.5+45` → `1.5.0+50`)
7. Push para `origin/feature/multi-app-e-badge-pro`. **Não fazer merge nem tag** — Cesar decide.

---

## Fora de âmbito (NÃO fazer neste sprint)

- Alterar as EFs no Supabase. Cowork trata.
- Criar novas apps além de POS e Fist. Não.
- Gestão de licenças Fist manualmente pelo Control (activar/prolongar). Fica para sprint futuro quando Cesar precisar realmente disso.
- Redesign visual do dashboard. Não. Apenas adicionar selector + badges.
- Alterar autenticação. Não.

---

**Fim do prompt.** Se algo aqui contradizer o código real que encontrares, **para e reporta ao Cesar antes de decidir sozinho**.
