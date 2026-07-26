# Control aprova pedidos do Punho

Como o admin global do Decisão Digital Control aprova, recusa e revoga o acesso
de utilizadores da app **Punho**.

**Não confundir** com `pedidos_acesso` / `PedidosAcessoScreen`, que são os
acessos ao próprio Control (equipa do escritório). São namespaces separados de
propósito e não foram tocados nesta ronda.

---

## 1. Onde vive o quê

| Camada | Ficheiro |
|---|---|
| SQL | `D:\Punho\supabase\migrations\20260801_punho_aprovacao_pelo_control.sql` |
| Testes SQL | `D:\Punho\supabase\tests\punho_aprovacao_test.sql` |
| Repositório | `lib/repositories/punho_admin_repository.dart` |
| Ecrã | `lib/features/acessos/punho/punho_pedidos_screen.dart` |
| Diálogos | `lib/features/acessos/punho/punho_decidir_modal.dart` |
| Separador | `lib/features/nav/home_shell.dart` (5.º, só para admin) |

A migration ficou no repo do Punho, junto do resto do schema dessa app, como
pedido. Os dois repos falam com o mesmo projecto Supabase, por isso
`public.is_admin()` (definido em `washinvoice_control/supabase/rls_policies.sql`)
está disponível para as RPCs do Punho.

---

## 2. Fluxo

### Aprovar

O admin abre **Punho** → filtro **Pendentes** → **Decidir**.

**Origem `convite`** — a empresa vem do convite e não se escolhe. O diálogo
diz qual é e o botão aprova. O servidor lê `convite_id → punho_convites →
empresa_id` e **ignora** qualquer `p_empresa_id` que o cliente mande. O perfil é
o que o convite fixou (gravado no pedido pelo trigger de registo).

**Origem `livre`** — o admin escolhe entre:
- *Criar nova* com o nome que a pessoa indicou no registo, mais um limite de
  utilizadores (por omissão 1);
- *Anexar a existente*, com dropdown que mostra a ocupação `ativos / limite`.

Em qualquer dos casos, quem pediu acesso livre fica **gestor** da empresa.

Em ambos os casos a escrita em `punho_membros` é
`on conflict (user_id) do update`.

### Recusar

Só de `pendente`. Muda o estado e não toca em `punho_membros`. Depois de
aprovado, tirar acesso é **revogar**, não recusar — e a RPC recusa-se a fazê-lo,
com mensagem que diz porquê.

### Revogar

Só de `aprovado`. Põe `punho_membros.ativo = false` e o pedido em `revogado`.
Nunca apaga. O diálogo de confirmação diz quem perde o acesso, de que empresa,
que liberta uma vaga e que nada é apagado.

O utilizador perde o acesso no arranque seguinte da app Punho — é aí que o
`AcessoGate` consulta `punho_meu_acesso()`.

### Reabrir

Um pedido `recusado` ou `revogado` mostra **Reabrir**, que é o mesmo diálogo de
decisão. Aprovar reactiva o membro.

---

## 3. Decisões de arquitectura

### O limite de utilizadores vive na subscrição, não na empresa

`punho_empresas` não tem coluna de limite. Quem o guarda é
`punho_subscricoes.limite_colaboradores_ativos`, criado em `20260725_punho_core`.
Acrescentar `limite_utilizadores` a `punho_empresas` criaria uma segunda fonte
de verdade para o mesmo número. `p_limite_utilizadores` vai para a subscrição, e
`punho_listar_empresas_admin()` lê de lá — expondo-o com o nome
`limite_utilizadores`, que é o vocabulário do Control.

Aprovar um pedido livre com empresa nova faz o mesmo que a antiga
`punho_criar_empresa_inicial` fazia: empresa + subscrição + instalação.

### Toda a escrita passa por uma RPC

Nenhuma policy de escrita foi aberta a `authenticated` nas tabelas do Punho. As
três funções são `security definer` com `search_path = public`, verificam
`is_admin()` à cabeça, e têm `execute` revogado de `public` e `anon`. A UI não
faz UPDATE em `punho_membros` — não tem por onde.

### `is_admin()` é a única porta

O gate é do lado do servidor. O separador escondido na UI é conveniência, não
segurança: mesmo que alguém chegue ao ecrã, as RPCs recusam.

### O separador só aparece ao admin

`HomeShell` observa `souAdminGlobalProvider`. Um gerente de organização não vê
"Punho" — em vez de lhe bater com um erro ao entrar. O índice do
`BottomNavigationBar` é limitado com `clamp`, porque o perfil só é conhecido
depois do primeiro build e a lista de separadores pode encolher.

### Ícone distinto

`Icons.approval` para Punho, `Icons.manage_accounts_outlined` para Acessos. São
coisas diferentes — clientes de uma app vs. equipa do escritório — e o custo de
as confundir é aprovar a pessoa errada no sítio errado.

### O filtro multi-app não se aplica

O selector `Todas | WashInvoice | Punho` da AppBar não afecta este ecrã: por
definição é sempre Punho. `appFilterProvider` não é observado em
`punho_pedidos_screen.dart`, e está comentado lá para não parecer esquecimento.

### Os diálogos não sabem o que é rede

`PunhoDecidirModal` e `PunhoRevogarModal` recebem dados já carregados e
devolvem uma `DecisaoPunho` por `Navigator.pop`. Quem chama a RPC é o ecrã.
Assim os diálogos montam-se em teste sem Supabase nenhum, que é o que os três
ficheiros de teste fazem.

### Feedback durante a chamada

`LinearProgressIndicator` no topo e todos os botões desactivados enquanto a RPC
corre — a decisão escreve em até quatro tabelas e não é instantânea.

---

## 4. Casos de fronteira considerados

| Caso | O que acontece |
|---|---|
| **Admin aprova e depois apaga a empresa à mão** | `punho_pedidos_acesso.empresa_id` tem FK sem cascade → o `delete` da empresa falha enquanto houver pedidos a apontar-lhe. `punho_membros.empresa_id` também tem FK. Ou seja: a base **não deixa** ficar um pedido órfão apontando para uma empresa que já não existe. Se o admin forçar (apagando membros e pedidos primeiro), o pedido desaparece com eles. |
| **Convite apagado antes de o pedido ser aprovado** | `punho_pedidos_acesso.convite_id` tem FK sem cascade, portanto o convite não se apaga sozinho. Se mesmo assim a empresa do convite não for resolúvel, a RPC recusa com mensagem explícita em vez de criar uma empresa à sorte. |
| **Reaprovar quem já pertence a outra empresa** | O `on conflict (user_id) do update` **muda** a empresa do membro. É intencional: o índice único em `punho_membros(user_id)` só admite uma empresa por conta. O admin está a mover a pessoa, não a duplicá-la. |
| **Aprovar acima do limite de utilizadores** | **Não é bloqueado.** O diálogo avisa a vermelho quando a empresa escolhida está cheia, e o admin decide. Está alinhado com o princípio "nada é automático" — o limite é uma questão comercial, não uma regra técnica. Ver "Por decidir". |
| **Aprovar duas vezes o mesmo pedido** | É idempotente: reescreve o membro com `ativo = true` e o pedido continua `aprovado`. Não cria nada em duplicado. |
| **Recusar um pedido aprovado** | Recusado pela RPC, com mensagem a dizer que o caminho é revogar. |
| **Revogar um pedido pendente** | Recusado pela RPC — não há acesso para tirar. |
| **Revogar quem nunca chegou a ter linha em `punho_membros`** | O `update` não apanha nada, `membro_id` vem nulo, e o pedido fica `revogado` na mesma. Sem erro. |
| **Pedido livre com organização indicada vazia** | O trigger de registo já põe "Empresa por confirmar"; a RPC ainda faz `coalesce` para "Empresa sem nome". Nunca cria empresa com nome vazio. |
| **Limite escrito à mão como texto** | O campo cai em 1. Testado. |
| **Dois admins a decidir o mesmo pedido ao mesmo tempo** | `select ... for update` no pedido serializa as duas decisões. A segunda vê o estado já mudado pela primeira e, se for recusar/revogar, é rejeitada pelas guardas de transição. |

---

## 5. Estado da entrega

| | |
|---|---|
| `flutter test` (Control) | ✅ **199 → 220** verdes |
| `flutter analyze` (Control) | ✅ limpo (só o `anonKey` deprecated pré-existente) |
| Migration SQL | ✅ escrita, idempotente — **por aplicar** |
| Testes SQL | ✅ escritos — **por correr** |
| `pubspec.yaml` | ✅ intacto em `1.8.1+26` |

O SQL não foi aplicado a nenhum projecto Supabase, como combinado. As instruções
de aplicação estão no cabeçalho da migration.

## 6. Por decidir / fora do âmbito

- **Não enforçar o limite de utilizadores na aprovação.** Hoje o admin pode
  ultrapassá-lo com um aviso. Se isso passar a ser proibido, é uma guarda a
  acrescentar em `punho_decidir_pedido`.
- **Gerir `punho_empresas` do Control** (renomear, mudar limite) — v0.0.4.
- **Convites do lado do Control** — não; quem convida é o gestor, na app Punho.
- **Push quando entra um pedido Punho novo** — por avaliar.
