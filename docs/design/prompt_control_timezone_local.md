# Prompt Code Control — timezone local em timestamps

> Cola numa sessão nova do Claude Code em `D:\WashInvoiceControl\washinvoice_control\`.
> Branch: **`feature/timezone-local`** a partir de `feature/mostrar-ip-telefone` (o último branch entregue).
> Alvo: bug reportado pelo Cesar em 22/07/2026 — Control mostra timestamps 1h atrás do real (Supabase guarda em UTC, Control não converte para local). Task #101.

---

## Contexto

Cesar testou o EXE 2.0.6 + APK 1.6.2 hoje. Confirmou que tudo funciona (push, hostname, IP, versão, kill-switch). Mas encontrou: card "Último acesso" mostra "22/07/2026 às 10:56" quando o momento real era 11:56 — 1h a menos, exactamente o offset entre UTC e Portugal WEST no verão.

**Causa:** `created_at` da Supabase é `timestamptz` (guardado em UTC). O Flutter parseia com `DateTime.parse(...)` que devolve `DateTime` **em UTC** (com `isUtc = true`). Ao formatar directamente com `intl` sem chamar `.toLocal()`, mostra a hora UTC.

**Fix:** um helper único que aplica `.toLocal()` antes de formatar, chamado em todos os sítios que hoje formatam timestamps.

---

## Autorizações já dadas

- Sem gates intermédios. Só o gate final: Cesar refresca o Detalhe do cliente e confirma que a hora agora bate certo.
- Bump patch: APK **1.6.3**.

---

## Restrições duras

- **NÃO tocar** em nada além dos widgets que mostram timestamps.
- **NÃO alterar** o modelo `Ping`, `Licenca`, `SerieComunicada` — a data continua a chegar em UTC via `DateTime.parse`.
- **NÃO alterar** o schema Supabase (timezone continua UTC, como deve ser).

---

## Fase 1 — Inventário (reportar em <150 palavras)

Grep no repo por sítios que formatam timestamps sem `.toLocal()`:

```bash
grep -rn "criadoEm\|created_at\|criadoEm.year\|criadoEm.day" lib/ --include="*.dart"
grep -rn "DateFormat\|intl.*format" lib/ --include="*.dart"
grep -rn "timeago" lib/ --include="*.dart"
```

Reportar cada linha + o que renderiza. Provavelmente:
- `detalhe_cliente_screen.dart` (card Último acesso — bug identificado).
- Modal historial `licencas_audit`.
- `DetalhePedidoAjudaScreen`.
- `PingHistoricoScreen` (se existir).

---

## Fase 2 — Helper único

Novo `lib/core/formatacao.dart` (ou juntar ao `Exibicao` existente se fizer sentido):

```dart
import 'package:intl/intl.dart';

class Formatacao {
  Formatacao._();

  /// Converte UTC -> local antes de formatar. Formato PT: "22/07/2026 às 11:56".
  static String dataHoraLocal(DateTime utc, {String locale = 'pt_PT'}) {
    final local = utc.toLocal();
    final data = DateFormat('dd/MM/yyyy', locale).format(local);
    final hora = DateFormat('HH:mm', locale).format(local);
    return '$data às $hora';
  }

  /// Só a data, também convertida para local.
  static String dataLocal(DateTime utc, {String locale = 'pt_PT'}) {
    return DateFormat('dd/MM/yyyy', locale).format(utc.toLocal());
  }

  /// Data + hora + segundos (para historial detalhado).
  static String dataHoraSegundosLocal(DateTime utc, {String locale = 'pt_PT'}) {
    return DateFormat('dd/MM/yyyy HH:mm:ss', locale).format(utc.toLocal());
  }
}
```

Se já existe algum helper de formatação (por ex. em `core/exibicao.dart`), integrar lá em vez de criar novo ficheiro. Reutilizar padrão do projecto.

---

## Fase 3 — Substituir em todos os call-sites

Em cada widget identificado na Fase 1:
- Substituir formatação manual por `Formatacao.dataHoraLocal(dateTime)` (ou o formato que fizer sentido).
- Confirmar visualmente que a hora passa a bater com a hora local.

`timeago.format(...)` já usa hora relativa e não sofre do bug em geral, mas se estiver a usar `.difference(DateTime.now())` sem `.toLocal()` do lado UTC, verificar. Se dúvida, deixar comentário e reportar.

---

## Fase 4 — Testes

Novo `test/core/formatacao_test.dart`:

- `dataHoraLocal(DateTime.utc(2026, 07, 22, 10, 56))` — em Portugal WEST devolve `22/07/2026 às 11:56`.
- `dataLocal(DateTime.utc(2026, 12, 15, 23, 30))` — em Portugal WET (inverno) devolve `15/12/2026`. (Cuidado: teste de inverno + verão pode variar consoante o CI runner — se o ambiente do teste for UTC, verificar o offset esperado.)
- Widget test em `detalhe_cliente_screen`: pumpear com Ping cujo `criadoEm=DateTime.utc(2026, 07, 22, 10, 56)` → verificar que renderiza `22/07/2026 às 11:56` (assumindo runner em WEST). Se runner for UTC (comum), o teste pode passar `10:56` — nesse caso mockar `DateTime.now()` ou usar `timezone` package se necessário.

`flutter test` verde. `flutter analyze` limpo.

---

## Fase 5 — Compilar APK 1.6.3

1. Bumpar `pubspec.yaml`: `1.6.3+22` (a partir de 1.6.2+21).
2. `flutter build apk --release`.
3. Reportar caminho do APK.

---

## Fase 6 — Reconciliação

1. Actualizar `docs/estado_e_roadmap.md` do Control.
2. Reportar SHAs + caminho do APK.
3. Fecha task #101.

---

## Teste manual (Cesar)

1. Instala APK 1.6.3.
2. Abre Detalhe do cliente de teste.
3. Confirma que o "Último acesso" agora bate com a hora local (WEST = UTC+1 em Julho).
4. Confirma o mesmo em outros sítios com timestamps: modal historial de licencas_audit, DetalhePedidoAjudaScreen, etc.

---

## Commits sugeridos

1. `core: Formatacao com toLocal antes de formatar`
2. `ui: usar Formatacao.dataHoraLocal em todos os widgets de timestamps`
3. `test: cobertura timezone`
4. `docs: reconciliação timezone local`
5. `release: bump 1.6.3 + APK`

Reporta SHAs + caminho do APK. Sem merge até OK do Cesar.
