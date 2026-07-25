# Prompt Code Control — Auto-update MVP (só Control, primeira metade)

> Cola numa sessão nova do Claude Code em `D:\WashInvoiceControl\washinvoice_control\`.
> Branch: **`feature/auto-update-control`** a partir do último branch estável (após merge do timezone se já mergeado; senão a partir de `feature/timezone-local`).
> Alvo: Control passa a verificar se há APK novo, mostrar banner e permitir descarregar. **Este sprint NÃO toca no POS** — auto-update do POS fica para sprint próprio a seguir. Task #100 (parte Control).
> Bump: APK **1.7.0** (agrupa auto-update + resto do que estiver em cadeia).

---

## Contexto

Cesar reconheceu que sem auto-update, cada actualização exige reinstalação manual. Este sprint entrega a parte do Control primeiro (mais simples de testar — Cesar tem telemóvel próprio para exercitar). Depois de o Control estar a funcionar, arranca-se sprint próprio para o POS que reutiliza a infra Supabase criada aqui.

**Escopo:**
- Tabela nova na Supabase `versoes_apps` para catalogar versões disponíveis por app (fica preparada também para o POS futuro).
- Edge Function nova `versao-mais-recente` que responde à pergunta "há build novo para esta app?".
- Cliente Flutter no Control que consulta ao arranque + a cada 6h.
- Banner de UI que se activa quando há actualização disponível.
- Suporte a **update obrigatório** — modal bloqueante.

---

## Autorizações já dadas

- Migration aditiva Supabase — aplica via MCP directamente.
- Deploy da Edge Function nova — via MCP directamente.
- Sem gates intermédios até ao teste manual final.
- Bump Control para **1.7.0** (agrupa com o resto que estiver na cadeia).

---

## Restrições duras

- **NÃO tocar** em código do POS (`D:\WashFactura\`) — repo separado, sprint separado.
- **NÃO tocar** em Edge Functions existentes.
- **NÃO** modificar `validar-licenca` — usar Edge Function nova para separação limpa.
- **NÃO** implementar auto-install (Play Store fica para v2 futura, quando o negócio justificar 25€ da conta developer).

---

## Fase 1 — Migration Supabase (aditiva, aplica via MCP directamente)

```sql
create table if not exists versoes_apps (
  id uuid primary key default gen_random_uuid(),
  app text not null check (app in ('pos', 'control')),
  versao text not null,
  build_number integer not null,
  url_download text not null,
  data_lancamento timestamptz not null default now(),
  obrigatoria boolean not null default false,
  notas_lancamento text,
  activa boolean not null default true,
  unique (app, build_number)
);

comment on table versoes_apps is 'Catálogo de versões dos apps WashInvoice (POS Windows) e WashInvoiceControl (Android). Edge Function versao-mais-recente devolve a versão activa com build_number mais alto.';

create index if not exists idx_versoes_apps_app_activa
  on versoes_apps(app, build_number desc) where activa = true;

-- Seed com a versão actual do Control (para exercitar depois com valores falsos)
insert into versoes_apps (app, versao, build_number, url_download, obrigatoria, activa)
values
  ('control', '1.7.0', 23, 'https://github.com/CesarM78/washinvoice-releases/releases/download/control-1.7.0/WashInvoiceControl_v1.7.0.apk', false, true)
on conflict (app, build_number) do nothing;
```

**Nota:** o `url_download` do seed vai ser um URL placeholder. Cesar terá de criar o release no GitHub e actualizar o URL via SQL antes do build final ir para as mãos de clientes. Explicar em `docs/`.

---

## Fase 2 — Edge Function `versao-mais-recente`

Novo `supabase/functions/versao-mais-recente/index.ts`. `verify_jwt: true`, service_role internamente.

Endpoint: `POST /functions/v1/versao-mais-recente`

Body:
```json
{
  "app": "control",
  "build_number_local": 21
}
```

Resposta se houver actualização:
```json
{
  "actualizacao_disponivel": true,
  "versao_actual": "1.7.0",
  "build_number": 23,
  "url_download": "https://...",
  "obrigatoria": false,
  "notas_lancamento": "..."
}
```

Resposta se estiver actualizada:
```json
{ "actualizacao_disponivel": false }
```

**Implementação:**

```ts
const { app, build_number_local } = await req.json();
if (!['pos', 'control'].includes(app)) {
  return json(400, { erro: 'app inválida' });
}

const { data: v, error } = await supabase
  .from('versoes_apps')
  .select('versao, build_number, url_download, obrigatoria, notas_lancamento')
  .eq('app', app)
  .eq('activa', true)
  .order('build_number', { ascending: false })
  .limit(1)
  .maybeSingle();

if (error) return json(500, { erro: error.message });
if (!v || build_number_local >= v.build_number) {
  return json(200, { actualizacao_disponivel: false });
}
return json(200, {
  actualizacao_disponivel: true,
  versao_actual: v.versao,
  build_number: v.build_number,
  url_download: v.url_download,
  obrigatoria: v.obrigatoria,
  notas_lancamento: v.notas_lancamento,
});
```

Deploy via MCP.

---

## Fase 3 — Cliente Flutter no Control

### 3.1 — Modelo `ActualizacaoInfo`

`lib/models/actualizacao_info.dart`:

```dart
class ActualizacaoInfo {
  final String versaoActual;
  final int buildNumber;
  final String urlDownload;
  final bool obrigatoria;
  final String? notasLancamento;

  const ActualizacaoInfo({
    required this.versaoActual,
    required this.buildNumber,
    required this.urlDownload,
    required this.obrigatoria,
    this.notasLancamento,
  });

  factory ActualizacaoInfo.fromJson(Map<String, dynamic> json) => ActualizacaoInfo(
    versaoActual: json['versao_actual'] as String,
    buildNumber: json['build_number'] as int,
    urlDownload: json['url_download'] as String,
    obrigatoria: json['obrigatoria'] as bool? ?? false,
    notasLancamento: json['notas_lancamento'] as String?,
  );
}
```

### 3.2 — Serviço `ActualizacaoService`

`lib/services/actualizacao/actualizacao_service.dart`:

```dart
class ActualizacaoService {
  final SupabaseClient _supabase;
  ActualizacaoService(this._supabase);

  Future<ActualizacaoInfo?> verificar() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final buildLocal = int.parse(packageInfo.buildNumber);
    final sessao = _supabase.auth.currentSession;
    if (sessao == null) return null;

    final r = await _supabase.functions.invoke(
      'versao-mais-recente',
      body: {'app': 'control', 'build_number_local': buildLocal},
      headers: {'Authorization': 'Bearer ${sessao.accessToken}'},
    ).timeout(const Duration(seconds: 10));

    final data = r.data;
    if (data is! Map<String, dynamic>) return null;
    if (data['actualizacao_disponivel'] != true) return null;
    return ActualizacaoInfo.fromJson(data);
  }
}
```

### 3.3 — Provider Riverpod

```dart
final actualizacaoServiceProvider = Provider((ref) => ActualizacaoService(supabase));
final actualizacaoDisponivelProvider = StateProvider<ActualizacaoInfo?>((_) => null);
```

### 3.4 — Verificar no arranque + timer 6h

No ponto de entrada do Control (`main.dart` ou `app.dart`), após autenticação:

```dart
Future<void> _verificarActualizacao(WidgetRef ref) async {
  try {
    final info = await ref.read(actualizacaoServiceProvider).verificar();
    if (info != null) ref.read(actualizacaoDisponivelProvider.notifier).state = info;
  } catch (_) { /* fail silent */ }
}

// Chamar no arranque
await _verificarActualizacao(ref);

// Timer periódico
Timer.periodic(const Duration(hours: 6), (_) => _verificarActualizacao(ref));
```

---

## Fase 4 — UI: Banner de actualização

Novo `lib/features/actualizacao/banner_actualizacao.dart`:

```dart
class BannerActualizacao extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(actualizacaoDisponivelProvider);
    if (info == null) return const SizedBox.shrink();

    return Container(
      color: info.obrigatoria ? Colors.red.shade100 : Colors.amber.shade100,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(info.obrigatoria ? Icons.warning : Icons.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nova versão ${info.versaoActual} disponível',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (info.notasLancamento != null && info.notasLancamento!.isNotEmpty)
            TextButton(
              onPressed: () => _mostrarNotas(context, info),
              child: const Text('Ver o que mudou'),
            ),
          ElevatedButton(
            onPressed: () => launchUrl(Uri.parse(info.urlDownload),
                mode: LaunchMode.externalApplication),
            child: const Text('Descarregar'),
          ),
          if (!info.obrigatoria)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(actualizacaoDisponivelProvider.notifier).state = null,
            ),
        ],
      ),
    );
  }
}
```

**Se `obrigatoria = true`:** o banner aparece como modal bloqueante em cima de toda a UI. O utilizador não pode fechar sem descarregar (para casos de bug crítico fiscal/segurança). Implementar via `Dialog` que se recusa a `pop` até `launchUrl` ser chamado.

**Se `obrigatoria = false`:** banner persistente no topo do `home_screen`. Botão X fecha para esta sessão (volta a aparecer no próximo arranque ou timer se ainda houver actualização).

Integrar o `BannerActualizacao` no `Scaffold` de topo do Control (`home_screen.dart` ou `main_screen.dart`), imediatamente abaixo do `AppBar`.

---

## Fase 5 — Testes

Unitários:
- `test/services/actualizacao/actualizacao_service_test.dart` — mock Supabase, verificar body com `app: 'control'`, parse de resposta com/sem actualização.
- `test/models/actualizacao_info_test.dart` — fromJson com e sem `notas_lancamento`.

Widget:
- `test/features/actualizacao/banner_widget_test.dart`:
  - Provider vazio → banner não aparece.
  - Provider com actualização não obrigatória → banner amarelo com X.
  - Provider com actualização obrigatória → banner vermelho sem X.
  - Carregar em "Descarregar" → chama `launchUrl` (mock).

`flutter test` verde. `flutter analyze` limpo.

---

## Fase 6 — Compilar release 1.7.0

1. Bumpar `pubspec.yaml`: `1.7.0+23`.
2. `flutter build apk --release`.
3. Reportar caminho do APK.

---

## Fase 7 — Reconciliação

1. Actualizar `docs/estado_e_roadmap.md` do Control.
2. `supabase/functions/versao-mais-recente/README.md` com curl exemplo.
3. `docs/negocio/auto_update.md` — processo de lançamento (como Cesar cria release no GitHub + actualiza URL na BD via SQL). Explicar que para o POS há sprint próprio a seguir.
4. Reportar SHAs + caminho do APK.
5. Fecha task #100 (parte Control).

---

## Teste manual (Cesar)

1. **Preparar release fake para exercitar:** Cesar cria repo público `CesarM78/washinvoice-releases` no GitHub (só clique — sem código). Faz "Create new release" com tag `control-1.7.0` e anexa o APK compilado. Copia URL do asset.
2. **Actualizar URL na BD via SQL** (Cesar ou Cowork faz via MCP):
   ```sql
   update versoes_apps set url_download = '<URL_real>' where app='control' and build_number=23;
   ```
3. Instalar APK 1.7.0 (não vai mostrar banner porque local == remoto).
4. **Simular update disponível:** inserir versão fake mais alta na BD:
   ```sql
   insert into versoes_apps (app, versao, build_number, url_download, obrigatoria, activa)
   values ('control', '1.7.1', 24, '<mesmo URL>', false, true);
   ```
5. Fechar e reabrir o Control (ou esperar 6h).
6. **Deve aparecer banner amarelo:** "Nova versão 1.7.1 disponível" + botão "Descarregar".
7. Carregar "Descarregar" → abre browser Android → começa download.
8. Testar obrigatória: `update versoes_apps set obrigatoria=true where build_number=24`. Reabrir Control → banner passa a modal bloqueante.
9. Limpar fake: `delete from versoes_apps where build_number=24`.

Se todos os passos passam → autoriza merge.

---

## NÃO TOCAR EM

- Motor fiscal, licenciamento (não aplicável ao Control).
- Edge Functions existentes.
- Repo do POS (`D:\WashFactura\`) — sprint separado.

---

## Regras

- Português europeu.
- Update obrigatório é **bloqueante** — usar quando houver bug de segurança ou fiscal crítico. Cesar activa via SQL.
- Se rede off durante `launchUrl`, browser Android trata do erro; app não crasha.
- APK 1.7.0 vai agrupar-se ao APK do webservice séries (task #89) quando o certificado AT chegar — coordenar merges.

---

## Commits sugeridos

1. `db: migration versoes_apps + Edge Function versao-mais-recente`
2. `actualizacao: ActualizacaoService + provider + timer 6h`
3. `actualizacao: banner UI com descarregar + modal obrigatorio`
4. `test: cobertura service + widget`
5. `docs: reconciliação auto-update Control`
6. `release: bump 1.7.0 + APK`

Reporta SHAs + caminho do APK. Sem merge até OK do Cesar após teste manual.
