# Multi-app — arquitectura

> 25/07/2026 · v1.8.0 · task #177 incluída
> Contexto: o Control passou a ser o backoffice de todas as apps da Decisão Digital,
> não só do WashInvoice POS.

---

## 1. Decisão: coluna `app` vs tabelas separadas

Havia três caminhos para separar os dados do POS dos do Punho.

| Opção | O que era | Porque não |
|---|---|---|
| **Tabelas separadas** (`licencas_pos`, `licencas_punho`) | Uma tabela por app | Cada app nova obriga a criar 6 tabelas, 6 conjuntos de policies RLS e 6 caminhos de código. O Dashboard "Todas as apps" passaria a fazer `UNION` à mão em todo o lado. Duplicação que cresce linearmente com o número de apps. |
| **Projecto Supabase por app** | Isolamento total | O Control teria de manter N clientes Supabase e N sessões de autenticação. Uma vista agregada ("quantas instalações tenho ao todo?") tornava-se impossível sem um serviço a fazer fan-out. Custo real por projecto. |
| **Coluna `app`** ✅ | Uma coluna discriminadora nas tabelas existentes | Escolhida. |

**Porquê a coluna.** As entidades são as mesmas em todas as apps: uma licença é uma
licença, um ping é um ping. O que muda é de que produto vieram — isso é um atributo,
não um tipo diferente. Com a coluna, "todas as apps" é ausência de `WHERE`, e uma app
nova é um valor novo no CHECK: zero migrações estruturais, zero código novo nos
repositórios.

O preço é que uma app com campos próprios teria de os pôr em colunas nullable ou num
JSONB. Aceitável enquanto POS e Punho partilharem o modelo de licenciamento — que é
todo o ponto de terem o mesmo backoffice. Se um dia divergirem a sério, a conversa
volta a abrir-se.

## 2. `NOT NULL` sem default — de propósito

A coluna não tem default. Um `DEFAULT 'pos'` teria sido mais cómodo de migrar, mas
transformava o esquecimento de alguém em dados silenciosamente errados: um terminal
Punho registado sem `app` ficaria a contar como POS e ninguém daria por isso até os
números não baterem certo. Sem default, o INSERT rebenta na hora e o bug aparece em
desenvolvimento, não em produção.

Consequência prática no código: **todo o `.insert()` nestas tabelas tem de incluir
`app`**. Ver `Licenca.toInsertJson()` e `LicencasRepository.criar()`.

## 3. Como o filtro atravessa a app

```
WiAppSelector (AppBar)
      ↓ escreve
appFilterProvider  ──persiste──▶  SharedPreferences['app_filtro']
      ↓ ref.listen                 ↓ .valorApp  ('pos' | 'punho' | null)
  ecrã recarrega            repositório: if (app != null) q = q.eq('app', app)
```

**O filtro aplica-se no servidor, não em memória.** Filtrar client-side significaria
trazer o parque inteiro para o telemóvel a cada carregamento e deitar fora metade —
e, pior, os KPIs teriam de ser recalculados em dois sítios diferentes.

**Porque não `FutureProvider`.** O prompt original previa converter os ecrãs para
`FutureProvider` com `ref.watch(appFilterProvider)`. Não se fez: os ecrãs deste
projecto são `ConsumerStatefulWidget` com `late Future<_XData> _future` carregado no
`initState`, e converter dois ecrãs grandes era uma reescrita da camada de dados a
troco de nada visível. Usa-se `ref.listen(appFilterProvider, …) → _recarregar()`,
que dá o mesmo comportamento com quatro linhas por ecrã.

## 4. Onde o filtro **não** se aplica

Duas excepções deliberadas, ambas comentadas no código:

- **Exportar dados** (`backup_screen.dart`) — um backup filtrado seria um backup
  incompleto sem o anunciar. Exporta sempre tudo, e os CSV levam agora coluna `app`.
- **Pesquisa global** (`pesquisa_global_screen.dart`) — é o escape à vista filtrada.
  Com o selector em Punho, procurar um cliente POS tem de o encontrar, não devolver
  "sem resultados". Os resultados levam badge de app sempre visível.

Uma terceira, de natureza diferente: a **ficha do cliente** filtra pela app *daquela
licença*, não pelo filtro global — a contagem "Terminal 2 de 3" conta terminais da
mesma app, e um cliente com POS e Punho não deve vê-los somados.

## 5. Uma app desconhecida não é erro

`AppsUi` (em `lib/core/apps_ui.dart`) trata qualquer valor fora de `pos`/`punho` como
app desconhecida: mostra o valor em maiúsculas, a cinzento. Isto é intencional — uma
app nova pode aparecer na base de dados (registada por uma Edge Function) antes de
sair uma versão do Control que a conheça. Melhor mostrar `[LAVANDARIA]` do que
rebentar ou esconder a linha.

`AppsUi` é o sítio único para "dado `pos`/`punho`: que sigla, que nome, que cor, que
ícone", à imagem do `estado_ui.dart`. As cores saem dos tokens (`tokens.md` §1), não
de hex avulsos: azul de marca para o POS, verde para o Punho, com os pares
pastel/forte já validados para contraste.

## 6. Push: o que o cliente pode e não pode fazer

`tituloComApp()` (em `lib/services/push_titulo.dart`) prefixa o título com a sigla da
app. **Só afecta o SnackBar de foreground.**

Com a app em background ou fechada, quem desenha a notificação é o sistema operativo,
a partir do payload `notification` que a Edge Function `enviar-push` envia — o Dart
nem chega a correr (o `fcmBackgroundHandler` só faz log). Para `[PUNHO] Novo terminal`
aparecer na barra de notificações, **o prefixo tem de vir já no título enviado pela
Edge Function**. Isso é do lado do Supabase, não deste repo.

## 7. Badge PRO (#177) e o tier legado

`WiTierBadge` mostra o badge quando `tier.temExtras` — ou seja **pro e legado**, não
só pro.

O `Tier.legado` existe para licenças anteriores ao modelo Base/Pro e o modelo
documenta que "comporta-se como pro — não se retiram funcionalidades a quem já as
tinha". Mostrar o badge só a `pro` faria uma licença legado (com todos os extras
activos) aparecer visualmente igual a uma Base. Hoje não há linhas legado na base de
dados, mas `TierInfo.parse` manda para lá tudo o que não reconhece, portanto a regra
tem de estar certa antes de haver o primeiro caso.

## 8. Ficheiros

| Ficheiro | Papel |
|---|---|
| `lib/core/apps_ui.dart` | Sigla, nome, cores e ícone por app |
| `lib/core/app_filter/app_filter_provider.dart` | `AppFiltro` + estado global persistido |
| `lib/core/widgets/wi_app_selector.dart` | Selector da AppBar |
| `lib/core/widgets/wi_app_badge.dart` | `WiAppBadge` + `WiAppBadgeAuto` (esconde-se com filtro fixo) |
| `lib/core/widgets/wi_tier_badge.dart` | Badge PRO (#177) |
| `lib/services/push_titulo.dart` | Prefixo `[POS]` / `[PUNHO]` no push de foreground |
