# Prompt Code Control — fechar a ronda de bugs desta sessão de teste

> Cola no Code do Control já aberto no branch `feature/painel-controlo-remoto`.
> Migração `admins_e_is_admin` já feita. Function `gerir-licenca` v2 deployed. Este ficheiro fecha o que falta antes do APK final.

---

## Autorizações já dadas (sem gates intermédios)

- Rebuild APK release directamente no fim.
- Sem confirmação intermédia. Só o gate final: reporta SHAs quando estiver tudo verde, Cesar faz teste manual.

---

## Contexto

Testes revelaram 4 problemas no Control. Um deles (`gerir_licenca_service.dart`) já tem o edit aplicado directamente pelo Cowork — falta ao Code auditar callers similares e fazer commit. Os outros três são acréscimos pequenos ao `DetalheClienteScreen`.

---

## Fase 1 — Fix do 401 na `gerir-licenca` (edit já aplicado)

Bug: `supabase_flutter functions.invoke` auto-injecta anon key no `Authorization`. `verify_jwt: true` passa mas `getUser()` na function não sabe quem chama → 401 "não autenticado".

**Fix já aplicado por mim** em `lib/services/licenca/gerir_licenca_service.dart` — injecta o session token explicitamente:

```dart
final sessao = supabase.auth.currentSession;
if (sessao == null) {
  throw const GerirLicencaException('sem sessão activa — inicia sessão de novo');
}
final r = await supabase.functions
    .invoke(
      'gerir-licenca',
      body: body,
      headers: {'Authorization': 'Bearer ${sessao.accessToken}'},
    )
    .timeout(const Duration(seconds: 15));
```

Ao Code — fazer:

1. **Auditar** o resto do código (`grep functions.invoke`) por outros callers que dependam de auth do utilizador. Aplicar o mesmo padrão a cada um. Não tocar em callers que usem secret partilhado (`enviar-push`).
2. Adicionar teste em `test/services/licenca/gerir_licenca_service_auth_test.dart`: mock sem sessão → excepção; mock com sessão → header `Authorization: Bearer <token>` é passado.
3. Actualizar `supabase/functions/README.md` linha ~24 para clarificar: "POS chama com JWT anon (auto-injectado). Control chama com session token do utilizador (injectado explicitamente pelo cliente Flutter)."

---

## Fase 2 — Cabeçalho do `DetalheClienteScreen` mostra `nome_comercial` + `designacao_social`

Migration `licencas.nome_comercial` e `clientes.nome_comercial` já aplicada. Quando o Code do POS terminar o sprint paralelo, o campo passa a ser populado — o Control tem de estar pronto.

### 2.1 — Modelo

Em `lib/models/licenca.dart` e/ou `lib/models/cliente.dart`, adicionar `nomeComercial: String?`. `fromMap` lê `nome_comercial`. `toMap` inclui-o.

### 2.2 — Repositórios

Se os `select()` em `licencas_repository.dart` / `clientes_repository.dart` explicitam colunas, adicionar `nome_comercial`.

### 2.3 — UI cabeçalho do `DetalheClienteScreen`

Substituir o título actual por:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      licenca.nomeComercial?.isNotEmpty == true
          ? licenca.nomeComercial!
          : (licenca.nome ?? 'Sem nome'),
      style: theme.textTheme.titleLarge,
      overflow: TextOverflow.ellipsis,
    ),
    if (licenca.nomeComercial?.isNotEmpty == true && licenca.nome?.isNotEmpty == true)
      Text(
        licenca.nome!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        overflow: TextOverflow.ellipsis,
      ),
  ],
)
```

Regra:
- Ambos preenchidos → título grande = `nome_comercial`, subtítulo pequeno = `nome` (designação social).
- Só `nome` → título grande, sem subtítulo.
- Ambos vazios → "Sem nome".

Mesmo padrão em `_CartaoInstalacao` na `InstalacoesScreen`.

---

## Fase 3 — Card "Último acesso" reformulado (fundir Sinal + Sinal diz)

Bug UX: duas linhas separadas "Sinal" (método) e "Sinal diz" (cidade) confundem — parecem dois sinais quando é um só.

Novo layout do card `_CardUltimoAcesso`:

```
Último acesso
Quando:          [data/hora formatada, ex. 18/07/2026 12:41]
GPS:             [cidade traduzida]         ← rótulo dinâmico
Loja:            [licenca.localidade ou empresa.localidade]
Versão do POS:   [versão]
```

### Regra do rótulo dinâmico (baseado em `p.metodoGeo`)

Actualizar `lib/core/exibicao.dart`:

```dart
/// Rótulo do método de geolocalização — usado como label da linha KV.
static String rotuloSinal(String? metodoGeo) {
  switch (metodoGeo) {
    case 'gps': return 'GPS';
    case 'ip': return 'IP';
    case 'nenhum':
    default:
      return 'Sem sinal';
  }
}
```

E na UI, substituir as duas linhas actuais (`Sinal` + `Sinal diz`) por uma só `WiLinhaKV`:

```dart
WiLinhaKV(
  rotulo: Exibicao.rotuloSinal(p.metodoGeo),
  valor: p.metodoGeo == null || p.metodoGeo == 'nenhum'
      ? '—'
      : (Localidades.traduzir(p.cidade).isEmpty ? '—' : Localidades.traduzir(p.cidade)),
),
```

**Manter** ícone e cor à esquerda do rótulo (verde/laranja/cinza) para pista visual rápida.

Adicionar linha "Loja:" com valor de `licenca.localidade` ou `empresa.localidade` — o que o admin configurou nos dados de empresa. Se divergir do valor da linha GPS/IP, salta à vista.

Aplicar mesmo padrão em `DetalhePedidoAjudaScreen` (mesmo layout de card).

---

## Fase 4 — Testes

- `test/services/licenca/gerir_licenca_service_auth_test.dart` — sem sessão → excepção; com sessão → header enviado.
- `test/models/licenca_test.dart` — `fromMap` lê `nome_comercial`.
- `test/features/instalacoes/detalhe_cliente_widget_test.dart`:
  - Cabeçalho com ambos os nomes → título grande = comercial, subtítulo = designação.
  - Só designação → título grande = designação, sem subtítulo.
  - Ambos vazios → "Sem nome".
- `test/core/exibicao_test.dart` — `rotuloSinal('gps') == 'GPS'`, `rotuloSinal('ip') == 'IP'`, `rotuloSinal(null) == 'Sem sinal'`.

`flutter test` verde. `flutter analyze` sem novos avisos.

---

## Fase 5 — Reconciliação + build APK

1. Actualizar `docs/estado_e_roadmap.md` do Control.
2. Actualizar `supabase/functions/README.md` linha ~24 (nota sobre injecção manual do session token).
3. Reportar SHAs de commit.
4. `flutter build apk --release` (ou `--split-per-abi` se for o padrão do projecto).
5. Reportar caminho do APK gerado.
6. Tasks fechados: #78, #85, #87.

Sem merge até OK do Cesar após teste manual do APK novo.

---

## NÃO TOCAR EM

- Máquina de estados de licença (POS).
- Auth do Control (só usar `currentSession.accessToken` — não mexer no fluxo de login).
- Notificações push (não afectadas).
- Preferências individuais de features (só read-only).

---

## Commits sugeridos

1. `licenca: injectar session token em gerir-licenca invoke + auditar outros callers`
2. `detalhe_cliente: cabeçalho mostra nome_comercial + designacao_social`
3. `ultimo_acesso: fundir Sinal + Sinal diz numa só linha (GPS/IP: cidade)`
4. `ultimo_acesso: adicionar linha Loja com localidade da empresa`
5. `test: cobertura auth + widget + exibicao`
6. `docs: reconciliação`

Reporta SHAs + caminho do APK.
