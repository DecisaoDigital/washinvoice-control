# WashInvoice Control — Design Tokens

Fonte de verdade visual para o redesign do companion Android. Deriva da
paleta de marca já confirmada em `washinvoice/references/ui-visual.md`
(POS Windows) — não introduz cores novas, só as sistematiza para mobile.

---

## 1. Cor

### 1.1 Base de marca (herdada do POS — não alterar)

| Nome | Hex | Uso |
|---|---|---|
| Azul | `#2B95D9` | Marca, info, acção neutra |
| Verde | `#5CB036` | Confirmar, positivo, activo |
| Roxo | `#534AB7` | Pendente, atenção secundária |
| Laranja | `#F97316` | Aviso, a expirar |
| Vermelho | `#DC2626` | Erro, destrutivo, expirado |

### 1.2 Escalas derivadas (calculadas, não estimadas)

Cada cor-base gera 5 tons por mistura matemática com branco/preto — para
fundos pálidos, bordas, texto sobre cor, e estados pressed/hover.

| Escala | Azul | Verde | Roxo | Laranja | Vermelho |
|---|---|---|---|---|---|
| 50 (fundo pálido) | `#F2F9FD` | `#F5FAF3` | `#F5F4FB` | `#FFF7F1` | `#FDF2F2` |
| 100 (fundo chip) | `#E6F2FA` | `#EBF6E7` | `#EAE9F6` | `#FEEEE3` | `#FBE5E5` |
| 200 (borda activa) | `#BFDFF4` | `#CEE7C3` | `#CBC9E9` | `#FDD5B9` | `#F4BEBE` |
| 500 (base) | `#2B95D9` | `#5CB036` | `#534AB7` | `#F97316` | `#DC2626` |
| 700 (superfície dominante) | `#2277AE` | `#4A8D2B` | `#423B92` | `#C75C12` | `#B01E1E` |
| 900 (texto sobre 50/100 / AppBar) | `#1F5F87` | `#33611E` | `#2E2965` | `#893F0C` | `#791515` |

> **Reconciliação v1.4:** `azul-900` passou de `#185277` (proposto) para **`#1F5F87`**,
> o tom adoptado como superfície da AppBar em todos os ecrãs do redesign. Texto
> branco sobre `#1F5F87` dá ~6:1 (passa WCAG AA em qualquer tamanho) e serve
> também como texto escuro sobre `azul-50/100` (ex.: chip de filtro activo).
> O código (`AppColors.azul900`) é a implementação desta linha.

### 1.3 Regra de contraste (verificada, não assumida)

Branco sobre `azul-500` (#2B95D9) dá **3.28:1** — falha WCAG AA para
texto normal (mín. 4.5:1), passa à justa para texto grande/negrito (mín. 3:1).

**Regra:** superfícies grandes com texto branco (AppBar, fundo do Login,
botões primários com label) usam **`azul-700`** (#2277AE → 4.86:1,
passa AA em qualquer tamanho). `azul-500` fica reservado para ícones,
bordas, acentos e chips — nunca como fundo sólido atrás de texto branco.

### 1.4 Neutros

| Nome | Hex | Uso |
|---|---|---|
| Fundo | `#F0F0F0` | Scaffold background (mantido do actual) |
| Superfície | `#FFFFFF` | Cards |
| Texto primário | `#2C2C2A` | Títulos, valores |
| Texto secundário | `#5F5E5A` | Rótulos, metadados |
| Texto terciário | `#9E9D9B` | Timestamps, placeholders |
| Borda subtil | `#E2E2E0` | Divisores, outline inputs em repouso |

### 1.5 Mapeamento semântico (estados de licença — já correcto, preservar)

| Estado | Cor |
|---|---|
| Activa | Verde 500 |
| A expirar | Laranja 500 |
| Expirada | Vermelho 500 |
| Suspensa | Texto terciário |
| Pendente (pedido renovação) | Roxo 500 |

---

## 2. Tipografia

Fonte: **Roboto** (mantida — Segoe UI do POS é Windows-only e não
renderiza em Android; assunção explícita, a confirmar se preferires
outra fonte do sistema Android).

| Token | Tamanho | Peso | Uso |
|---|---|---|---|
| display | 28px | 700 | Wordmark no Login |
| h1 | 20px | 700 | Título de ecrã (quando não é AppBar) |
| h2 | 16px | 700 | Título de secção/card |
| body | 14px | 400 | Texto corrente |
| body-strong | 14px | 600 | Nome de cliente, valores |
| label | 12px | 500 | Rótulos de campo, metadados |
| caption | 11px | 400 | Timestamps, hints |
| mono | 13px | 400 (monospace) | Machine ID, URLs — **sempre truncado com opção de expandir**, nunca em bruto num card de listagem |

---

## 3. Espaçamento

Escala base 4px (consistente com o padrão já usado no código: 4, 8, 12, 16, 20, 24).

| Token | Valor |
|---|---|
| space-1 | 4px |
| space-2 | 8px |
| space-3 | 12px |
| space-4 | 16px |
| space-5 | 20px |
| space-6 | 24px |
| space-8 | 32px |

Padding padrão de ecrã: `space-4` (16px) — mantido.
Gap entre cards de lista: `space-2` (8px) — mantido.

---

## 4. Raios

| Token | Valor | Uso |
|---|---|---|
| radius-sm | 8px | Inputs, chips pequenos |
| radius-md | 12px | Cards (mantido — já consistente no `CardThemeData`) |
| radius-pill | 999px | Botões de filtro, badges, CTA principal |

Problema actual a corrigir: campos de formulário usam ~8px mas o
segmented button e chips usam pill (999px) sem ligação visual. Regra
nova: **inputs e cards = radius-md (12px)**, nunca 8px — unifica com o
`CardThemeData` já definido no tema. Só filtros/badges/CTAs usam pill.

---

## 5. Elevação / sombra

Tema actual já define `elevation: 1` nos cards — manter. Regra nova:
**nunca usar cor sólida de fundo em vez de sombra para destacar um
card** (é a causa directa do card cinzento "Início de actividade" no
Dashboard — deveria destacar-se por elevação + acento de cor na borda
esquerda, não por um preenchimento sólido escuro).

| Token | Elevação | Uso |
|---|---|---|
| elevation-0 | 0 | Fundo, AppBar (flat, já definido) |
| elevation-1 | 1 | Cards normais |
| elevation-2 | 3 | Card em destaque (ex.: nova instalação a activar) |

---

## 6. Iconografia

Manter Material Icons (já em uso, consistente). Ícones semânticos a
confirmar/trocar:

| Contexto | Ícone actual | Problema |
|---|---|---|
| Nova instalação | `Icons.fiber_new` | Badge "NEW" redundante — a secção já se chama "Início de atividade" |
| Mapa (BottomNav) | `Icons.map` | OK no código; o ícone que pareceu "livro" no screenshot é o próprio `Icons.map` mal interpretado a baixa resolução — não é bug |

---

## 7. Correcções mapeadas por problema identificado

| Problema | Token/regra que resolve |
|---|---|
| D1/A1 — machine_id em 4 linhas | `mono` token com truncamento (8 chars + "…") por defeito; texto completo só na vista de detalhe com `SelectableText` |
| D2 — card "Início de actividade" cinzento inerte | `elevation-2` + borda esquerda `azul-500` (4px) em vez de fundo sólido; fundo passa a `azul-50` |
| D3 — "A expirar (≤15d)" parte em 2 linhas | `label` a 12px (actual é 11px) cabe numa linha em 4 colunas iguais; alternativa: abreviar para "A expirar" e mover "≤15d" para tooltip/caption |
| D4/I1/A2/S3 — AppBar sem identidade | AppBar passa a `azul-700` (não `azul-500`) — resolve também o contraste; adicionar ícone `local_laundry_service` pequeno antes do título, ecoando o Login |
| D5 — badge NEW redundante | Remover `Icons.fiber_new`; manter só o CTA "Ativar" |
| D6 — metade do ecrã vazia | Fora do âmbito de tokens — resolve-se em mockup (ver secção de Dashboard) |
| I3 — chips de filtro invisíveis | Chip inactivo usa borda `texto-terciário` a 100% opacidade (não 40%) sobre fundo branco, não sobre o fundo cinza da página |
| A5 — segmented button sem selecção visível | Estado vazio (`emptySelectionAllowed`) precisa de affordance própria — hint visual "escolhe um plano ou define duração manual" |
| S1 — URL parte a meio da palavra | `mono` token + `overflow: TextOverflow.ellipsis` com toque para copiar (já usa `SelectableText`, só falta truncar) |

---

## 8. Componentes reutilizáveis a criar (a partir destes tokens)

Depois destes tokens ficarem no `AppColors`/`AppTheme`, criar em `lib/core/widgets/`:

| Widget | Substitui | Racional |
|---|---|---|
| `WiCard` | `Card` directo | Padding, raio, elevação consistentes (`elevation-1`, `radius-md`, `padding: space-4`) |
| `WiCardDestaque` | Card cinzento actual da "Início de actividade" | Fundo `azul-50` + borda esquerda `azul-500` (4px) + `elevation-2`. Convida à acção. |
| `WiKpiCard` | Cards KPI actuais | Icon + número (`h1` size mas w700 a 28px) + label. Labels uniformes, sem qualificadores que quebram alinhamento. |
| `WiSecaoTitulo` | Literais dispersos + `_Seccao` no Sobre | Token `h2` (16px w700). |
| `WiLinhaKV` | `_Linha` interno em vários ecrãs | Rótulo width 100 (`label`, `texto-secundário`) + valor (`body-strong`). |
| `WiBadgeEstado` | `BadgeEstado` existente | Reforçar semântica de cor da tabela 1.5. |
| `WiChipEstado` | `ChipEstado` existente | idem. |
| `WiChipFiltro` | Chips actuais em `_barraFiltros` | Correcção I3 (border cinzenta 100% opacidade sobre branco). |
| `WiEmptyState` | Estados vazios ad-hoc | Ícone `space-6` acima do texto centrado. |

**Regra:** todos usam apenas tokens deste ficheiro. Nunca cores/valores mágicos directos. Se um componente novo precisar de valor não tokenizado, actualiza-se este documento primeiro.

---

## 9. Cobertura de ecrãs novos (features adicionais na mesma ronda)

Ecrãs que ainda não existem mas serão criados nesta ronda de redesign:

### Pedidos de Ajuda (Control)

Cliente carrega em "Pedir Ajuda" no POS → INSERT na tabela `pedidos_ajuda` do Supabase → trigger dispara push para o Cesar. Este ecrã lista os pedidos.

- Cada pedido: `WiCardDestaque` (é accionável — carregar liga por `tel:` ao número do cliente).
- Estado: `WiBadgeEstado` com semântica **novo** (laranja), **em atendimento** (azul), **resolvido** (verde), passado a texto tertiário quando resolvido.
- Padding, tipografia e cores derivam da mesma paleta — nada especial.

### Sugestões (Control)

Cliente envia sugestão pelo POS (formulário livre) → INSERT em `sugestoes` + `mailto:` paralelo. Este ecrã lista o histórico.

- Cada sugestão: `WiCard` padrão (informativo, não accionável).
- Texto em `body`, autor + data em `caption`.
- Ícone `star_outlined ↔ star` (laranja) para marcar como importante.

Ambos aparecem como novas secções no Dashboard (não novas abas no bottom nav — não expandir a navegação).

---

## 10. Nota sobre a discrepância D2 (não resolvida)

O código define o card de nova instalação com `AppColors.azul.withValues(alpha: 0.07)` — deveria renderizar como azul muito pálido. O screenshot mostra cinzento sólido. Duas explicações possíveis, não confirmadas:

1. O build no telemóvel está desactualizado face a este código-fonte.
2. Existe outro `Container`/`Card` a sobrepor-se com cor diferente que não vi no ficheiro.

Os tokens desta secção resolvem o problema de qualquer forma (fundo `azul-50` explícito + borda de acento), por isso não bloqueia — mas fica registada para não assumir que o código actual está a produzir o visual que vês.

---

## 11. Regras de layout (armadilhas) — v1.4.1

Aprendidas com o bug crítico do Dashboard 1.4.0 (KPIs seguidos de ~28 páginas de
espaço morto em release):

- **Nunca usar `CrossAxisAlignment.stretch` num `Row`/`Column` cujo eixo cruzado
  é ilimitado.** Dentro de um `ListView`/`Column` scrollável, o filho recebe
  altura máxima **infinita**. Um `Row` com `stretch` tenta esticar os filhos até
  essa altura → altura infinita. Em debug dá assertion; em **release** as
  assertions são removidas e renderiza espaço morto gigante que empurra tudo
  para fora do ecrã. Se precisas de filhos com igual altura, envolve o `Row` em
  **`IntrinsicHeight`** (limita o eixo cruzado à altura do filho mais alto).
- **Um bug só de release exige verificação em release.** `flutter analyze`/`test`
  em debug apanham a assertion (bom para regressão), mas o sintoma real
  (espaço morto) só se vê no APK. Confirmar sempre no telemóvel.
