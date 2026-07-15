# Prompt para Claude Code (POS WashInvoice) — Coordenação com Control v1.4

> Cola numa sessão do Claude Code aberta no **repo do POS WashInvoice/WashFactura Windows** (não o Control).
> Antes de colares, actualiza `<PATH_DO_POS>` para o path real (ex: `D:\WashInvoice\` ou `D:\WashFactura\`).

---

## Contexto

Repo: `<PATH_DO_POS>` (POS Windows, Flutter + Drift/SQLite).
Estado actual: aproxima-se da v15, alvo de certificação AT.
Do lado do Control (repo separado, Android) foram criadas 4 features novas que **precisam do POS a enviar dados** para o Supabase:

1. **Pedidos de Ajuda** — cliente carrega botão → INSERT em `pedidos_ajuda` → push chega ao admin.
2. **Sugestões** — cliente escreve texto → INSERT em `sugestoes` + `mailto:` paralelo.
3. **Localidade humana** — cliente preenche na ficha da empresa → sync com `clientes.localidade` no Supabase.
4. **Diálogo Ajuda** com contactos WashInvoice (já estava planeado numa ronda anterior — inclui-se aqui para lançamento coordenado).

Esta ronda é **v1.6** do POS.

---

## Regra fundamental

Podes tocar em código do POS **desde que não afecte a lógica fiscal**. A regra explícita:

> "Não tocar no core que altera coisas para a AT, a não ser que seja melhoria imperativa."

**Considera "core fiscal" e não tocar:**

- `lib/core/fiscal_constants.dart`
- `lib/services/fiscal/` (todos os ficheiros)
- `lib/services/signing/` (assinatura de faturas)
- `lib/services/licenca/licenca_assinatura.dart` (HMAC — Ed25519 fica pós-AT)
- `lib/features/caixa/cobrar_screen.dart`, `movimento_caixa_screen.dart`, `fecho_turno_screen.dart`, `notas_credito_screen.dart`, `segunda_via_screen.dart`
- `lib/features/contabilista/*` (SAF-T, séries ATCUD, IVA)
- `lib/data/db/tables.dart` para tabelas `documentos_fiscais`, `series`, ATCUD (podes ADD nova tabela ou coluna em `empresa`, mas NUNCA mexer nas existentes das fiscais)
- Hash chaining, formato de PDF/A, assinatura, ordem de campos no XML SAF-T

**Podes tocar (âmbito desta ronda):**

- `lib/features/licenca/ecra_bloqueio.dart`, `ecra_boas_vindas.dart`, `licenca_banner.dart` — adicionar botões novos.
- `lib/features/licenca/compra_licenca.dart` — substituir SnackBar por AlertDialog com contactos (feature 4).
- `lib/features/admin/dados_empresa_screen.dart` — acrescentar campo `localidade`.
- `lib/core/constants.dart` — acrescentar constantes de contacto.
- `lib/data/db/tables.dart` — ADD coluna `localidade` na tabela `empresa` (ADD, não ALTER a outras).
- `lib/data/repositories/empresa_repository.dart` — actualizar leitura/escrita da nova coluna.
- Nova pasta `lib/features/suporte/` para os ecrãs Pedir Ajuda + Enviar Sugestão.
- `pubspec.yaml` — versão sobe para 1.6.0.

---

## Fase 1 — Inventário (não escrever código)

Confirma:

1. Que a versão actual é `1.5.x`. Se for 1.6.x já, avisa (colisão).
2. Que `lib/data/db/tables.dart` tem uma tabela `empresa` com colunas actuais (dá a lista).
3. Que `lib/data/repositories/empresa_repository.dart` existe e como se lê/escreve.
4. Que `lib/features/admin/dados_empresa_screen.dart` existe (é onde vou pôr o campo `localidade`).
5. Que `lib/features/licenca/compra_licenca.dart` ainda usa SnackBar (ronda anterior para diálogo não foi executada).
6. Se já existe alguma pasta ou ecrã de "suporte/ajuda/sugestão" — não devia.
7. Testes actuais passam (`flutter test` verde).

Devolve inventário e plano de ficheiros a tocar. **Não avanças sem confirmação.**

---

## Fase 2 — Constantes de contacto

Em `lib/core/constants.dart` acrescenta (ou actualiza se já existirem):

```dart
const String kContactoNome     = 'Cesar Mendes';
const String kContactoTelefone = '+351 914 353 752';
const String kContactoEmail    = 'cesarmendes78@gmail.com';
const String kContactoMarca    = 'WashInvoice';
```

Não mexas em `kLicencaCompraUrl` — pode ficar vazio.

---

## Fase 3 — Botão "Ajuda" (diálogo com contactos)

Ficheiro: `lib/features/licenca/compra_licenca.dart` (substitui a função `abrirCompraLicenca`).

- Substitui o `ScaffoldMessenger.showSnackBar` por `showDialog<void>` que apresenta um `AlertDialog`:
  - Título: `Obter licença WashInvoice`.
  - Corpo em `SelectableText`s: descrição breve ("Contacte-nos para adquirir ou renovar a sua licença.") + linhas com nome, telefone, email (constantes acima). Cada linha com ícone à esquerda (`Icons.phone`, `Icons.email_outlined`).
  - Botões (em ordem):
    - `TextButton` "Enviar email" → `mailto:kContactoEmail` com subject `Pedido de licença WashInvoice` e body genérico ("Olá, gostaria de obter uma licença WashInvoice. Contactem-me para prosseguir. Obrigado.").
    - `TextButton` "Fechar" → `Navigator.pop`.
  - Se `kLicencaCompraUrl` deixar de estar vazio no futuro, acrescenta terceiro botão "Abrir página" que faz `launchUrl` — condicional.

Adiciona `url_launcher` ao `pubspec.yaml` se não estiver presente.

Nenhum outro ficheiro precisa de mudar — os ecrãs `ecra_boas_vindas` e `ecra_bloqueio` continuam a chamar `abrirCompraLicenca(context)`.

---

## Fase 4 — Coluna Localidade na empresa

### 4.1 Schema local (Drift)

Em `lib/data/db/tables.dart`, na tabela `empresa`:

```dart
TextColumn get localidade => text().nullable()();
```

Corre `flutter pub run build_runner build --delete-conflicting-outputs` para regenerar `.g.dart`.

Cria migration Drift para `schemaVersion` seguinte (ver `database.dart`), a fazer `ALTER TABLE empresa ADD COLUMN localidade TEXT`.

### 4.2 Repository

Em `lib/data/repositories/empresa_repository.dart`:

- Adiciona `String? get localidade` no getter/DTO.
- Adiciona no método `actualizar()` a escrita do novo campo.

### 4.3 Ecrã `dados_empresa_screen.dart`

Acrescenta um `TextFormField` novo:

- Label: `Localidade`.
- Helper text: `Como o WashInvoice Control vai apresentar a sua loja (ex.: "Loja de Alvalade", "Filial de Ermesinde")`.
- Não obrigatório.
- Guarda em `empresa.localidade`.

### 4.4 Sync com Supabase (`clientes.localidade`)

Quando o utilizador gravar a ficha da empresa, adicionalmente ao INSERT/UPDATE local, envia para o Supabase (fire-and-forget, como os pings):

```dart
// Pseudo-código, ajusta ao teu padrão actual em licenca_service.dart
try {
  await Supabase.instance.client
      .from('clientes')
      .update({'localidade': novaLocalidade})
      .eq('nif', nifDaEmpresa);
} catch (_) { /* ignorar */ }
```

Não bloqueia o fluxo local. Se falhar, o admin actualiza directamente no Supabase.

**Nota importante:** o Supabase pode ainda não ter uma linha em `clientes` para o NIF desta instalação (só é criada quando o admin activa a instalação no Control). Nesse caso o UPDATE devolve 0 rows, sem erro — a `localidade` será preenchida no INSERT feito pelo Control quando o admin criar o cliente. Documentar isto no comentário do código.

---

## Fase 5 — Ecrã "Pedir Ajuda"

Nova pasta `lib/features/suporte/`.

### 5.1 `pedir_ajuda_screen.dart`

- **AppBar** "Pedir Ajuda".
- **Corpo** com uma explicação curta:
  ```
  Se está com um problema com o WashInvoice e precisa de assistência,
  toque no botão em baixo. Vamos entrar em contacto consigo
  o mais rápido possível.
  ```
- **Campo de texto opcional** "Descreva o problema (opcional)" — max 3 linhas.
- **Botão principal** "Pedir Ajuda" (`FilledButton.icon`, `Icons.support_agent`, cor primária). Ao carregar:
  1. Faz `INSERT` em `pedidos_ajuda` via Supabase (anon key):
     ```dart
     await Supabase.instance.client.from('pedidos_ajuda').insert({
       'machine_id': machineId,
       'nif': nifDaEmpresa,
       'notas': _textoOpcional,
     });
     ```
  2. Mostra `SnackBar` "Pedido enviado. Vamos contactá-lo em breve." (verde).
  3. Volta ao ecrã anterior.
  4. Falhas de rede: `SnackBar` "Não foi possível enviar. Verifique a ligação à internet e tente novamente."
- **Botão secundário** "Contactar directamente" — abre o mesmo AlertDialog da Fase 3 (telefone/email).

### 5.2 Ligação a partir do menu do POS

Adiciona um item de menu (onde faz mais sentido no fluxo actual — provavelmente no menu superior ou no ecrã Admin) chamado "Pedir Ajuda" com ícone `support_agent`, que abre `PedirAjudaScreen`.

Se não houver menu apropriado, adiciona-o ao `admin_hub_screen.dart` como card novo.

---

## Fase 6 — Ecrã "Enviar Sugestão"

Em `lib/features/suporte/enviar_sugestao_screen.dart`:

- **AppBar** "Enviar Sugestão".
- **Texto motivacional** em destaque no topo:
  ```
  O WashInvoice cresce com a sua ajuda.

  Só com o envolvimento dos utilizadores como o Cesar
  conseguimos desenvolver funcionalidades no caminho certo.
  Se tem uma ideia — um botão que faria a diferença,
  um relatório que ajudaria, ou algo que o incomoda — diga-nos.
  Lemos todas as sugestões.
  ```
  (Adapta o nome — se souberes o nome do cliente, personaliza; senão fica "utilizadores".)

- **`TextFormField`** para o texto da sugestão — multiline, min 4 linhas, sem limite máximo prático.
- **Botão "Enviar"** (`FilledButton.icon`, `Icons.lightbulb_outline`) — ao carregar:
  1. INSERT em `sugestoes` via Supabase:
     ```dart
     await Supabase.instance.client.from('sugestoes').insert({
       'machine_id': machineId,
       'nif': nifDaEmpresa,
       'texto': _texto,
     });
     ```
  2. Em paralelo (fire-and-forget) abre `mailto:kContactoEmail` com subject `Sugestão WashInvoice — {nome empresa}` e body com o texto.
  3. `SnackBar` "Sugestão enviada. Obrigado!" (roxo, para diferenciar).
  4. Volta ao ecrã anterior.
  5. Falha: `SnackBar` "Não foi possível enviar. Guarde o texto e tente mais tarde."

Adiciona também ao menu (Admin ou onde apropriado) com ícone `lightbulb_outline`.

---

## Fase 7 — Bump de versão

`pubspec.yaml`: `version: 1.6.0+16` (patch/build à tua escolha).

---

## Fase 8 — Testes

Adiciona:

- `test/dialogo_ajuda_test.dart` — widget test que verifica que ao chamar `abrirCompraLicenca` aparece um AlertDialog com o telefone e o email.
- `test/empresa_localidade_test.dart` — teste do repo confirmando que `localidade` é lido e escrito.
- `test/pedir_ajuda_test.dart` — widget test que carrega no botão e verifica que se chama o Supabase client (com mock).
- `test/enviar_sugestao_test.dart` — idem para sugestão.

Corre `flutter test`. Não deve haver regressões nos testes existentes (assinatura fiscal, séries, etc.).
Corre `flutter analyze`. Zero avisos novos.

---

## Fase 9 — Verificação UI real

Compila e instala num Windows de teste. Regista em `docs/verificacao_pos_1_6.md`:

1. **Ecrã bloqueio → "Obter licença"** → aparece diálogo com contactos, botão email abre app default.
2. **Ecrã boas-vindas → "Comprar licença"** → mesmo diálogo.
3. **Admin → Dados da Empresa** → campo `Localidade` presente, aceita texto, guarda ao carregar em Guardar.
4. **Menu → "Pedir Ajuda"** → ecrã aparece. Botão "Pedir Ajuda" com internet activa insere linha em `pedidos_ajuda` (verifica no Supabase). Sem internet dá SnackBar de erro.
5. **Menu → "Enviar Sugestão"** → ecrã aparece com texto motivacional. Botão "Enviar" insere linha em `sugestoes` E abre app de email.
6. **Emitir factura normal** — nada mudou. Séries, ATCUD, hash, SAF-T — todos iguais ao antes desta ronda.
7. **SAF-T exportar** — ficheiro gerado igual ao esperado (comparar com anterior se possível).

**Sem regressões fiscais é o critério primeiro.** Se qualquer ponto 1-5 falhar por bug, mas 6-7 ficarem OK, a ronda pode ser lançada mesmo assim (features novas isoladas). Se 6-7 falharem, **stop tudo** e reverter.

---

## Fase 10 — Reconciliação da documentação

No fim, exactamente como no prompt do Control:

1. Audita este prompt secção a secção. Regista em `docs/design/prompt_pos_coordenacao_v1_6.md` (copiar deste prompt e acrescentar no fim uma secção `## Reconciliação — o que ficou vs planeado`) o que foi implementado como descrito, adaptado, adiado ou bloqueado.

2. Se houver `docs/estado_e_roadmap.md` no repo do POS, actualiza-o. Se não houver, cria um.

3. Se qualquer decisão arquitectural mudou durante a implementação, regista com "porquê".

**Regra dourada:** documentação nunca pode mentir sobre o código.

---

## NÃO TOCAR EM (repito para não haver dúvida)

- `lib/core/fiscal_constants.dart`
- `lib/services/fiscal/*`
- `lib/services/signing/*`
- `lib/services/licenca/licenca_assinatura.dart`
- `lib/features/caixa/*`
- `lib/features/contabilista/*`
- Nada nas tabelas `documentos_fiscais`, `series`, ou ATCUD.
- `lib/features/entrega/*` (fluxo de entrega ao cliente)
- `lib/features/fluxo/*` (contagem, prontas, retomar)
- `lib/features/admin/relatorio_mensal_screen.dart` (relatórios fiscais)
- Hash chaining ou qualquer algoritmo de assinatura de documentos.

Se um teste fiscal quebrar depois de uma alteração desta ronda, **é bug** — reverte e reporta antes de continuar.

---

## Regras

- Português europeu (ecrã, gravar, ligar, faturar).
- Cores/estilo consistente com o resto do POS actual — não introduzir tema novo (o POS é Windows, o redesign visual é só do Control Android).
- Fire-and-forget para todas as chamadas Supabase que não sejam críticas (mesma filosofia dos pings actuais).
- Se algum item do prompt não fizer sentido face ao código real, para e reporta.

---

## Ordem de commits sugerida

1. `constants: contactos WashInvoice`
2. `licenca: dialogo Ajuda com contactos (substitui SnackBar)`
3. `db: coluna localidade em empresa + migration Drift`
4. `empresa: campo Localidade no ecrã de dados`
5. `empresa: sync localidade para Supabase (fire-and-forget)`
6. `suporte: novo módulo — Pedir Ajuda`
7. `suporte: novo módulo — Enviar Sugestão`
8. `menu: entradas Pedir Ajuda e Enviar Sugestão`
9. `version: bump 1.6.0`
10. `test: dialogo, localidade, pedir ajuda, sugestão`
11. `docs: verificacao_pos_1_6.md`

Reporta SHA de cada. Não faças merge para `master` até validação real e OK do Cesar.
