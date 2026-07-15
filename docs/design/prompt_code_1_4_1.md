# Prompt para Claude Code — WashInvoice Control 1.4.1

> Cola este prompt na sessão do Code aberta em `D:\WashInvoiceControl\washinvoice_control\`.
> Branch de trabalho: **`feature/1.4.1-fixes`** a partir de `feature/redesign-visual`.
> Alvo: v1.4.1+15.

---

## Contexto

Depois de instalar a 1.4.0 no telemóvel, o Cesar reportou:

1. **BUG CRÍTICO** — Dashboard mostra só os 4 KPIs (todos a zero) seguidos de **espaço branco enorme** (≈28 páginas de scroll). Nenhuma secção aparece — nem as condicionais (Início de actividade, Pedidos de ajuda, A expirar, Pedidos de renovação, Sugestões), nem a "Actividade recente" que devia estar SEMPRE visível.
2. **Login sem `autofillHints`** — o Google Password Manager do Android nunca oferece guardar/preencher (Task 29 pré-existente).
3. **Dashboard não reage a push chegado** — quando entra novo pedido de ajuda ou nova instalação, o Dashboard não recarrega automaticamente. Cesar tem de tocar em refresh (Task 30 pré-existente).
4. **Push em foreground silencioso** — SnackBar aparece mas sem som/vibração. Notificações Android nativas têm som — o SnackBar em foreground não. Deve ser opção.

Backend está validado:

- Base tem 1 pedido de ajuda aberto (`nif=512345678`, notas "impressora térmica…").
- Base tem 18 pings do machine_id `8a0f8c93e2e71c852df08c1daca0d0481c76e0859854c9c51983edbb160e5fde`, todos SEM licença associada (0 licenças na base).
- Portanto `data.novasInstalacoes` e `data.pedidosAjuda` **deviam** vir com 1 item cada.
- Sessão do Cesar activa (`last_sign_in_at` recente, token FCM registado, email visível no Sobre/Sistema).
- RLS policies: `pings.select_pings` para authenticated, `pedidos_ajuda_admin_read` para authenticated. Cesar deve conseguir ler.

---

## Fase 1 — Investigação do bug crítico do Dashboard (não escrever código)

Este é o primeiro item e o mais importante. Ordem sugerida:

1. **Confirmar visualmente** — compila em debug, corre no telemóvel do Cesar (ou emulador), faz login com `cesarmendes78@gmail.com` + password que o Cesar te passar. Confirma que reproduzes o problema (KPIs 0/0/0/0 + espaço vazio + sem "Actividade recente").

2. **Logs de debug** — em `lib/features/dashboard/dashboard_screen.dart`, adiciona `dev.log()` no fim de `_carregar()`:
   ```dart
   developer.log(
     'Dashboard data: licencas=${licencas.length}, '
     'novas=${novas.length}, pedidosAjuda=${(await ajuda).length}, '
     'pedidosPendentes=${pendentes.length}, actividade=${acts.length}, '
     'sugestoes=${sugestoes.length}',
     name: 'dashboard'
   );
   ```
   Corre a app e observa o log. **Regista os números.** Este é o passo mais informativo.

3. **Hipóteses a testar em ordem**:
   - **H1 — Sessão sem role authenticated real**: talvez a sessão tem token válido mas o `role` no JWT não é `authenticated`. Chama `Supabase.instance.client.auth.currentSession?.accessToken` e decode o JWT (pode ser via `jwt_decoder` package temporariamente ou split manual e base64 decode). Verifica se `"role":"authenticated"` está no payload.
   - **H2 — Query devolve `List` em vez de `List<Ping>`**: se o parse falhar num item, retorna erro. Verifica que `Ping.fromJson` não lança para `pings` sem `nif`/`cidade`/etc (todos os campos nullable).
   - **H3 — Widget de layout com constraint infinita**: procura em `lib/core/widgets/` (ex: `WiCard`, `WiKpiCard`) qualquer uso de `Expanded`, `Flexible`, `MediaQuery.of(context).size.height`, `SizedBox(height: double.infinity)` ou `IntrinsicHeight`. Um destes fora de um `Row`/`Column` bounded pode criar altura infinita no `ListView` do Dashboard.
   - **H4 — `_CardActividade` com `pings.isEmpty` a devolver algo estranho**: reproduz caso vazio isoladamente para ver se o widget se comporta bem.
   - **H5 — Cache do FutureBuilder**: `_future` é set no `initState` mas talvez `didChangeDependencies` está a recriar sem esperar.

4. **Reportar findings** antes de tocar em código. Não presumir a solução — mostrar a evidência.

---

## Fase 2 — Correcções

Só depois da Fase 1 encontrar a raiz. Prováveis correcções por hipótese:

### 2.1 Fix Dashboard (dependente da Fase 1)

Aplicar o fix identificado. Verificar que:
- `_KpiRow` continua a mostrar zeros correctamente
- Se há `novasInstalacoes`, secção aparece com card
- Se há `pedidosAjuda`, secção aparece com cards e botão "Ver todos"
- "Actividade recente" aparece sempre — se `data.actividade.isEmpty`, mostra WiCard com "Sem actividade recente."
- Rodapé "WashInvoice Control · v1.4.1 · …" aparece no fundo
- Scroll é proporcional ao conteúdo, não infinito

Se a raiz for uma constraint infinita num Wi* widget, corrige o widget — não hard-coda no Dashboard.

### 2.2 `autofillHints` no Login (Task 29)

Em `lib/features/auth/login_screen.dart`, envolve os dois `TextFormField` num `AutofillGroup` e adiciona hints:

```dart
AutofillGroup(
  child: Column(
    children: [
      TextFormField(
        controller: _emailCtrl,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        keyboardType: TextInputType.emailAddress,
        ...
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: _passCtrl,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        ...
      ),
    ],
  ),
),
```

Testar em release build (autofill não aparece em debug consistente).

### 2.3 Auto-refresh do Dashboard ao receber push (Task 30)

Em `lib/main.dart`, o `_FcmForegroundListener` só faz `showSnackBar`. Estender:

```dart
_sub = FirebaseMessaging.onMessage.listen((mensagem) {
  // ... snackbar existente

  // Notificar Dashboard para recarregar. Usa um provider Riverpod
  // com StreamController que o Dashboard escuta em initState.
  final tipo = mensagem.data['tipo'] as String?;
  if (tipo == 'inicio_actividade' || tipo == 'pedido_ajuda') {
    _dashboardRefreshController.add(null);
  }
});
```

Criar `dashboardRefreshProvider` em `main.dart` (StreamProvider), e no `DashboardScreen.initState` adicionar listener que chama `_recarregar()` quando o stream emite.

### 2.4 Som/vibração em foreground (novo)

Duas abordagens:

**(a) Simples — vibrar quando SnackBar aparece:**
```dart
import 'package:flutter/services.dart';
...
HapticFeedback.mediumImpact();
```
Adiciona ao início do `onMessage.listen`.

**(b) Mais completa — mostrar notificação Android nativa mesmo em foreground:**
Adiciona `flutter_local_notifications` ao `pubspec.yaml`, configura canal de notificação Android, e no `onMessage.listen` cria uma notificação local em vez de/além do SnackBar.

**Escolher (a)** para esta ronda — mais simples, sem depender de package novo. Se o Cesar quiser (b) depois, faz-se em 1.4.2.

---

## Fase 3 — Testes

Adicionar/actualizar:

- `test/dashboard_test.dart` — widget test que:
  - Verifica que com data vazia, Dashboard mostra apenas KPIs + "Actividade recente" vazia + rodapé (sem scroll excessivo — verificar `tester.getSize(find.byType(ListView))` de altura razoável).
  - Verifica que com `novasInstalacoes` não vazia, secção aparece.
  - Verifica que com `pedidosAjuda` não vazia, secção aparece.
- `test/login_autofill_test.dart` — widget test que garante que os TextFields têm `autofillHints` correctos.
- Actualizar testes existentes que assumam o Dashboard vazio ter só os KPIs (não mudar o que já valida).

`flutter test` verde no fim. `flutter analyze` sem novos avisos.

---

## Fase 4 — Verificação UI real (obrigatória)

Compila release APK, instala no telemóvel. Regista em `docs/verificacao_apk_r1_4_1.md`:

1. **Login** — Google Password Manager oferece guardar depois do primeiro login. Ao voltar a abrir a app, sugere autofill.
2. **Dashboard após login** — mostra KPIs + "Início de actividade (1)" + "Pedidos de ajuda (1)" + "Actividade recente" com pelo menos 1 linha (o ping do próprio PC) + rodapé com versão 1.4.1. Sem scroll morto/enorme.
3. **Push chega com app aberta no Dashboard** — SnackBar + vibração. Dashboard recarrega sozinho (nova secção/item aparece sem tocar em refresh).
4. **Push chega com app em Instalações** — SnackBar + vibração. Ao voltar para Dashboard já mostra o novo item.
5. **Push chega com app em background** — notificação Android nativa com som normal do sistema.

Se algum destes falhar, marca como TODO no `verificacao_apk_r1_4_1.md` e reporta.

---

## Fase 5 — Reconciliação da documentação

No fim:

1. Actualiza `docs/estado_e_roadmap.md` — nova entrada "Ronda 1.4.1" na secção "O que foi entregue", com o que ficou fixado.
2. Fecha (ou remove) Tasks 29 e 30 nas notas (se existirem no repo).
3. Se a raiz do bug Dashboard for um erro de arquitectura (ex: widget Wi* com constraint mal), documenta em `docs/design/tokens.md` a regra para não voltar a acontecer.
4. Se o fix envolveu mudança de comportamento visível (ex: som em foreground), regista em "Decisões arquitecturais tomadas" do roadmap.

**Regra dourada** (do prompt v1.4): documentação nunca pode mentir sobre o código.

---

## NÃO TOCAR EM

- Backend Supabase (tabelas, policies, edge functions, triggers) — está a funcionar e testado.
- `lib/services/fcm_service.dart` e `fcm_background_handler.dart` — funcionam.
- Nada do POS Windows.
- `licenca_assinatura.dart` — HMAC continua até pós-AT.
- Componentes `Wi*` — só se um deles for a raiz do bug do Dashboard; nesse caso, corrigir e documentar.
- Rotas/navegação principal — só adicionar handler de auto-refresh.

---

## Regras

- Português europeu.
- Antes de fixes, evidência (Fase 1). Fixes especulativos são proibidos.
- Se o bug Dashboard não for reprodutível localmente, contactar o Cesar antes de improvisar — pode requerer dados específicos.
- Tokens (`docs/design/tokens.md`) são a fonte de verdade visual.

---

## Ordem de commits sugerida

1. `debug: logs no Dashboard para investigar dados vazios`
2. `fix(dashboard): <o que descobrires> — resolve scroll infinito e secções invisíveis`
3. `auth: autofillHints no LoginScreen (Task 29)`
4. `push: auto-refresh do Dashboard e vibração em foreground (Task 30 + som)`
5. `test: dashboard vazio, autofill hints`
6. `version: bump 1.4.1+15`
7. `docs: reconciliação + verificação`

Não faças merge para `master` sem OK do Cesar.
