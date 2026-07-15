# Prompt POS 1.6.7 — cidade em português no ping (ip-api `lang=pt`)

> Cola numa sessão do Claude Code aberta em `D:\WashFactura\`.
> Branch: **`feature/1.6.7-lang-pt`** a partir de master.
> Alvo: v1.6.7.

---

## Contexto

Actualmente a `_httpGetJson()` do `lib/services/licenca/licenca_service.dart` (linha ~698) chama o `ip-api.com` sem `lang=pt`, portanto os pings chegam ao Supabase com `cidade = "Lisbon"`, "Oporto", etc. No Control temos um tradutor EN→PT como fallback, mas a correcção definitiva é na origem — o próprio POS pede em português.

Zero impacto fiscal. Não toca em nada certificável.

---

## Fase 1 — Confirmar

Confirma na Fase 1:

1. Que a versão actual é `1.6.6+21`.
2. Que existe a linha:
   ```dart
   final j = await _httpGetJson('http://ip-api.com/json?fields=lat,lon,city');
   ```
   em `lib/services/licenca/licenca_service.dart` (~linha 698, dentro de `obterLocalizacao()`).
3. Que nenhum teste em `test/` faz referência ao URL literal (se fizer, tem que ser actualizado também).

Reportar. **Não avançar sem confirmação.**

---

## Fase 2 — Alteração única

Substitui a linha:

```dart
final j = await _httpGetJson('http://ip-api.com/json?fields=lat,lon,city');
```

por:

```dart
final j = await _httpGetJson('http://ip-api.com/json?fields=lat,lon,city&lang=pt');
```

Se houver constante pré-existente com esta URL, alterá-la no sítio único. Se aparecerem múltiplas ocorrências no código, alterar todas (mas só devia haver uma).

---

## Fase 3 — Bump de versão

`pubspec.yaml`: `version: 1.6.7+22`.

---

## Fase 4 — Testes

- Se houver teste que verifique o URL literal, actualizar para incluir `&lang=pt`.
- Correr `flutter test`. Verde.
- Correr `flutter analyze`. Zero avisos novos.

---

## Fase 5 — Verificação real

Compilar (Windows), instalar num PC de teste. Se possível:

1. Fazer arrancar o POS num PC com Wi-Fi normal (não VPN) para forçar geolocalização por IP (não GPS).
2. Aguardar o ping seguinte (arranque + a cada 6 h).
3. Verificar no Supabase (`select cidade from pings order by created_at desc limit 1`) que aparece `Lisboa` (ou o nome PT da cidade real) em vez de `Lisbon`.

Se não conseguires forçar (por exemplo o PC tem GPS que passa antes), documenta o TODO de validação — o fix é trivial e pode ser confirmado no próximo cliente novo que faça ping.

---

## Fase 6 — Reconciliação

1. Actualiza `docs/estado_e_roadmap.md` (ou equivalente no POS) com ronda 1.6.7 entregue.
2. No repo do Control (`D:\WashInvoiceControl\washinvoice_control\docs\estado_e_roadmap.md`, secção "Ronda POS 1.6.6"), altera a linha "Por confirmar: se `ip-api.com` já é chamada com `&lang=pt`" para "**Feito na 1.6.7**".

---

## NÃO TOCAR EM

- Core fiscal (séries, ATCUD, hash chaining, SAF-T, movimentos de caixa) — inalterado.
- Restante lógica do `licenca_service.dart` além da URL — não mexer.
- Constantes, configs, ou outras chamadas HTTP externas.

---

## Regras

- Português europeu (mesmo formal).
- Alteração é literal — sem interpretações criativas.
- Se por acaso a chamada já tiver `lang=pt` (contra o que verifiquei), reportar e parar.

---

## Commit único

`geo: ip-api lang=pt para cidade em português`

Reporta SHA. Merge para master fica em espera do OK do Cesar.
