# Prompt para Claude Code — WashInvoice Control 1.4.2

> Cola na sessão do Code aberta em `D:\WashInvoiceControl\washinvoice_control\`.
> Branch: **`feature/1.4.2-conteudo`** a partir de `master` (a 1.4.1 já foi merged? Se não, parte de `feature/1.4.1-fixes`).
> Alvo: v1.4.2+16.

---

## Contexto

Depois da 1.4.1 verificada no telemóvel, o Cesar identificou 3 problemas de **conteúdo/apresentação** (não são bugs de render — são dados mal tratados):

1. **"Início de actividade" mostra "NIF —"** quando o POS pré-licença ainda não tem NIF configurado. Feio. Deve ser `Sem NIF ainda`.

2. **Cidade em inglês** — o POS chama `http://ip-api.com/json?fields=lat,lon,city` que devolve `city` em inglês. Base tem "Lisbon" em vez de "Lisboa", "Oporto" em vez de "Porto". A correcção definitiva é acrescentar `&lang=pt` à URL no POS (fica para a **ronda 1.6 do POS**, já em preparação). No **Control**, adicionar tradutor por mapa para o que já está na base ficar bem representado.

3. **Fallback do `nomeDe()` mostra `?` ou hash** — quando o helper não encontra cliente, cai para o `machine_id` truncado ou "?" como último recurso. Cesar já disse claramente que **não quer ver o hash**. O fallback correcto é: `NIF <x>` se há NIF, senão texto descritivo tipo `Terminal sem identificação`.

Também, se `metodo_geo` estiver `null` em pings antigos, o ícone de sinal (`iconeSinal`) devia mostrar-se cinza barrado (`Icons.signal_wifi_off_outlined` ou similar) — verificar que já está assim.

---

## Fase 1 — Inventário (não escrever código)

Confirmar:

1. Onde está o helper `nomeDe()` — provavelmente `lib/core/exibicao.dart` ou `lib/core/contexto_instalacoes.dart`. Reportar assinatura actual + fallback actual.
2. Onde é chamado `ping.cidade` na UI: Dashboard (`_CardNovaInstalacao`, `_LinhaActividade`), Instalações, DetalheCliente, Mapa. Listar os sítios.
3. Onde é lido `ping.nif` na UI. Idem.
4. Como está a linha de `_CardNovaInstalacao` que hoje mostra "NIF ${ping.nif ?? '—'}".
5. Como está o `iconeSinal()` (em `exibicao.dart` ou similar) — quando `metodo_geo` é `null`, devolve o ícone certo (barrado)?

Reportar antes de tocar. **Não avançar sem confirmação.**

---

## Fase 2 — Alterações

### 2.1 Helper de tradução de cidades EN→PT

Cria `lib/core/localidades.dart`:

```dart
/// Tradução de cidades EN→PT.
///
/// A `ip-api.com` (usada pelo POS quando não há GPS) devolve nomes em inglês.
/// Este helper traduz os casos conhecidos; se não conhecer o nome, devolve
/// o valor original.
///
/// TODO(POS 1.6): mudar chamada para `?fields=lat,lon,city&lang=pt` no POS
/// e este helper passa a devolver o valor recebido (ainda cobre pings antigos).
class Localidades {
  Localidades._();

  static const _traducoes = {
    'Lisbon': 'Lisboa',
    'Oporto': 'Porto',
    'Bragança': 'Bragança',
    'Braga': 'Braga',
    'Coimbra': 'Coimbra',
    'Aveiro': 'Aveiro',
    'Faro': 'Faro',
    'Setúbal': 'Setúbal',
    // Adicionar mais consoante forem aparecendo na base.
  };

  /// Devolve o nome em português (se conhecido) ou o próprio valor.
  /// `null`/vazio → string vazia.
  static String traduzir(String? cidade) {
    if (cidade == null || cidade.trim().isEmpty) return '';
    final t = cidade.trim();
    return _traducoes[t] ?? t;
  }
}
```

### 2.2 Aplicar tradutor em todos os sítios onde `ping.cidade` aparece

Substituir `ping.cidade` directo por `Localidades.traduzir(ping.cidade)` (ou usá-lo dentro dos helpers `sinalLocalidadeDe`/`nomeDe` que consumam `pings.cidade`).

Sítios previstos (a confirmar na Fase 1):
- `lib/features/dashboard/dashboard_screen.dart` (`_CardNovaInstalacao`, `_LinhaActividade`)
- `lib/features/instalacoes/instalacoes_screen.dart` (linha "Sinal − Localidade")
- `lib/features/instalacoes/detalhe_cliente_screen.dart` (Sinal diz)
- `lib/features/mapa/mapa_screen.dart` (InfoWindow snippet)

### 2.3 Fallbacks correctos no `nomeDe()`

Regra em cascata:

1. Se **cliente conhecido** → `cliente.nome` (+ `· T<n>` se `>=2` terminais).
2. Senão, se **`nif` não vazio** → `NIF <nif>`.
3. Senão → `Terminal sem identificação`.

**Nunca mostrar hash de `machine_id` como fallback.** O `machine_id` continua a viver na secção "Máquina" do DetalheCliente (monospace + copiar) — nunca como identificador em listas.

### 2.4 "Sem NIF ainda" em `_CardNovaInstalacao`

Em `dashboard_screen.dart`:

```dart
Text(
  (ping.nif != null && ping.nif!.trim().isNotEmpty)
    ? 'NIF ${ping.nif!.trim()}'
    : 'Sem NIF ainda',
  style: AppText.bodyStrong,
),
```

### 2.5 Ícone de sinal quando `metodo_geo` é `null`

Verificar em `iconeSinal()`/`corSinal()`:
- `'gps'` → ícone location filled, verde
- `'ip'` → ícone wifi, laranja
- `'nenhum'` → ícone `signal_wifi_off_outlined` ou `antenna-off`, cinza
- `null` (não preenchido pelo POS) → mesmo comportamento que `'nenhum'`

Ajustar se necessário para tratar `null` como `'nenhum'`.

### 2.6 `_CardPedidoAjuda` mostra notas em vez de localidade

Actualmente o card do pedido de ajuda no Dashboard mostra `sinalLocalidadeDe(...)` na linha 2, o que cai em `? − ` quando o pedido não tem ping associado (caso típico — o pedido chega isolado, sem ping do próprio machine_id). Isso é feio e não informativo.

Substituir a linha 2 do card por **preview das notas do pedido** (mais útil ao admin — vê logo do que se trata):

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      ctx.nomeDe(machineId: pedido.machineId, nif: pedido.nif),
      style: AppText.bodyStrong,
    ),
    if (pedido.notas != null && pedido.notas!.trim().isNotEmpty) ...[
      const SizedBox(height: 2),
      Text(
        pedido.notas!.trim(),
        style: AppText.caption,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ],
    Text(
      'há $tempo${telefone != null ? ' · $telefone' : ''}',
      style: AppText.caption,
    ),
  ],
),
```

Se `notas` for null/vazio, a linha 2 desaparece — sem `?`, sem `−`, sem placeholder feio. Se `notas` existir, mostra até 2 linhas com ellipsis. Card fica compacto quando é pedido sem notas, expansivo quando é rico.

**Não mexer no `sinalLocalidadeDe` em si** — continua a ser útil noutros sítios (Instalações, DetalheCliente). Só este card é que passa a mostrar notas em vez de localidade.

### 2.7 Remover email do rodapé do Dashboard

Actualmente o rodapé mostra `WashInvoice Control · v1.4.0 · cesarmendes78@gmail.com`. Remover o email — desnecessário na UI principal (fica no Sobre/Sistema em secção "Contactos").

Novo rodapé:

```dart
Text(
  '${Config.marca} Control · v${data.versaoApp}',
  style: AppText.caption,
),
```

### 2.8 Novo ecrã `DetalhePedidoAjudaScreen`

Actualmente, tocar no card de Pedidos de Ajuda (Dashboard ou lista) mostra a mesma informação do card — inútil. Criar ecrã dedicado com toda a informação para o admin atender o pedido sem precisar de saltar entre ecrãs.

Ficheiro novo: `lib/features/pedidos_ajuda/detalhe_pedido_ajuda_screen.dart`.

**Layout (segue tokens já em uso):**

- **AppBar** azul-900: chevron voltar + título `nomeDe(...)` (cliente ou NIF) + chip estado (Aberto laranja / Resolvido verde).
- **Card "Pedido"** (`WiCard`, ícone `help_outline` laranja):
  - Notas completas (texto integral, seleccionável).
  - Criado em: data e hora + "há X".
  - Se resolvido: linha adicional "Resolvido em: data e hora + duração".
- **Card "Cliente/Terminal"** (ícone `store_outlined`):
  - Nome — `nomeDe(...)`.
  - NIF, localidade humana (`Localidades.traduzir` já aplicado).
  - Machine ID (monospace + botão copiar).
  - Estado da licença (activa/expirada/sem licença) — chip pequeno.
- **Card "Último ping"** (ícone `broadcast`):
  - Quando (timeago).
  - Sinal — ícone + método (GPS/Fornecedor internet/Sem sinal).
  - Cidade (do ping, traduzida).
  - Versão POS.
  - **Se não houver ping algum para este machine_id**, mostrar `WiCard` com "Sem pings deste terminal." (não hide — clareza).
- **Botões de acção grandes** (empilhados verticalmente com gap):
  - `Ligar` — `FilledButton.icon` primário azul-700, só se `cliente.telemovel != null`. Chama `tel:`.
  - `Enviar email` — `OutlinedButton.icon`, só se `cliente.email != null`. Chama `mailto:` com subject "Re: pedido de ajuda WashInvoice".
  - Se o pedido **está aberto**: `Marcar como resolvido` (verde filled).
  - Se **resolvido**: apenas informativo, sem botão de acção principal (arquivo).
- **Ver ficha completa do cliente** — `TextButton` que abre `DetalheClienteScreen(machineId: pedido.machineId)`.

**Navegação:**

- No Dashboard, `_CardPedidoAjuda.onTap` passa a abrir `DetalhePedidoAjudaScreen(pedido: p)` em vez do ecrã de lista.
- Em `PedidosAjudaScreen` (lista), tap num pedido abre o mesmo `DetalhePedidoAjudaScreen`.
- Depois de fechar, `.then((_) => _recarregar())` para reflectir "Marcar como resolvido".

**Não duplicar lógica**: o método `marcarResolvido(id)` continua no `PedidosAjudaRepository`. O ecrã de detalhe chama-o directamente.

### 2.9 Documentar TODO no POS

Em `docs/design/prompt_pos_coordenacao_v1_6.md` (se existir) ou em `docs/estado_e_roadmap.md`, acrescentar TODO:

- No POS, `licenca_service.dart`, mudar a chamada IP:
  ```
  http://ip-api.com/json?fields=lat,lon,city&lang=pt
  ```
  Assim os pings novos passam a chegar já em português.

---

## Fase 3 — Testes

Adicionar:

- `test/localidades_test.dart`:
  - `traduzir('Lisbon')` == `'Lisboa'`
  - `traduzir('Porto')` == `'Porto'` (idempotente)
  - `traduzir(null)` == `''`
  - `traduzir('  Lisbon  ')` == `'Lisboa'` (trim)
- `test/exibicao_test.dart` (actualizar):
  - `nomeDe` com cliente conhecido devolve nome (+ T<n> se ≥2).
  - `nomeDe` sem cliente mas com NIF devolve `NIF <x>`.
  - `nomeDe` sem cliente e sem NIF devolve `Terminal sem identificação` — **não** contém "8a0f8c93" nem substring de hash.
- Actualizar widget test do Dashboard (se existir) para verificar que quando `ping.nif == null` o card mostra `Sem NIF ainda`.

`flutter test` verde. `flutter analyze` limpo.

---

## Fase 4 — Verificação UI real

Compila release APK, instala. Regista em `docs/verificacao_apk_r1_4_2.md`:

1. **Dashboard → Início de actividade** — card mostra `Sem NIF ainda` (o teu PC ainda não tem NIF) e localidade `Lisboa` (não "Lisbon").
2. **Dashboard → Actividade recente** — a linha mostra `Terminal sem identificação` (ou `NIF X` se meteres um NIF) — **não vê "8a0f8c93.." em lado nenhum**.
3. **Dashboard → Pedidos de ajuda** — o pedido de teste mostra `NIF 512345678` na linha do nome + preview das notas ("A impressora térmica parou de imprimir talões…") na linha seguinte. **Sem `?` em lado nenhum.**
4. **Instalações** — se houver algum item, "Sinal − Localidade" mostra `Lisboa − …` (não Lisbon). Ícone de sinal correcto ou barrado se `metodo_geo` for null.
5. **DetalheCliente** — se abrires um, "Sinal diz" mostra `Lisboa`.
6. **Rodapé** do Dashboard mostra só `WashInvoice Control · v1.4.2` (sem email).
7. **Sem regressões** nos itens já verificados na 1.4.1 (autofill, auto-refresh, vibração).

---

## Fase 5 — Reconciliação da documentação

No fim:

1. Adiciona ronda 1.4.2 ao `docs/estado_e_roadmap.md` na secção "O que foi entregue".
2. Acrescenta em "Depois da aprovação AT" ou no roadmap POS o TODO do `lang=pt`.
3. Se algum sítio no código passou a depender de `Localidades.traduzir()`, documenta em `docs/design/tokens.md` (ou similar) a regra "cidade sempre passa por `Localidades.traduzir` antes de aparecer na UI".

**Regra dourada**: documentação nunca pode mentir sobre o código.

---

## NÃO TOCAR EM

- Backend Supabase.
- Edge Functions.
- FCM Service, background handler.
- Bug do Dashboard (já corrigido na 1.4.1 — não regredir o `IntrinsicHeight`).
- Nada do POS.
- `licenca_assinatura.dart`.

---

## Regras

- Português europeu (Lisboa, faturar, gravar).
- Se aparecer alguma cidade que a `_traducoes` não conheça, deixa passar como está (o helper devolve o valor original). Cesar acrescenta ao mapa quando encontrar.
- Tokens (`docs/design/tokens.md`) continuam a ser a fonte de verdade visual.

---

## Ordem de commits sugerida

1. `localidades: helper EN→PT para cidades de pings antigos`
2. `exibicao: nomeDe com fallback NIF/textual (sem hash)`
3. `dashboard: Sem NIF ainda no card de início de actividade`
4. `ui: aplicar Localidades.traduzir em todos os sítios com ping.cidade`
5. `sinal: metodo_geo null trata-se como nenhum`
6. `dashboard: remover email do rodapé`
7. `dashboard: _CardPedidoAjuda mostra preview de notas`
8. `pedidos_ajuda: novo DetalhePedidoAjudaScreen + navegação`
9. `test: localidades + exibicao + card pedidos com notas`
10. `version: bump 1.4.2+16`
11. `docs: reconciliação`

Não faças merge para `master` sem OK do Cesar.
