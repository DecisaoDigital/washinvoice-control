# Prompt para Claude Code — Redesign visual + features (v1.4.0)

> Cola este prompt inteiro numa sessão nova do Claude Code, aberta na raiz de `D:\WashInvoiceControl\washinvoice_control\`.
> Branch de trabalho: **`feature/redesign-visual`**.

---

## Contexto

Repo: `D:\WashInvoiceControl\washinvoice_control\`
Stack: Flutter + Riverpod + Supabase (companion Android do POS Windows WashFactura).
Estado actual: `feature/melhorias-r1-r2` já entregue (R1+R2 + FCM). Esta ronda é redesign visual completo + duas features novas (Pedidos de Ajuda, Sugestões), tudo numa branch nova. Suba a versão para **1.4.0**.

Antes de qualquer código, lê estes três ficheiros que já existem no repo:

- `docs/design/tokens.md` — paleta refinada, tipografia, espaçamentos, raios, elevações, componentes a criar, mapeamento problema→token. **É a fonte de verdade visual.**
- `docs/estado_e_roadmap.md` — visão geral do estado do projecto, decisões já tomadas.
- `supabase/contrato_apps.md` — o que o POS faz no Supabase e o que este redesign não pode partir.

Os mockups finais dos 6 ecrãs foram desenhados numa sessão de planeamento com o Cesar. Descrevo cada um em detalhe nas Fases 6 e 7 — segue essas descrições estritamente. Não inventes layout.

---

## Fase 1 — Inventário e confirmação (não escrever código)

Confirma:

1. Estrutura actual dos ficheiros que vão ser tocados (todos os ecrãs de `lib/features/`, `lib/core/app_colors.dart`, `lib/core/app_theme.dart`, `pubspec.yaml`).
2. Que a branch actual é `master` (ou similar) e podemos criar `feature/redesign-visual` a partir dela.
3. Que o teste suite actual (`flutter test`) passa antes de começares.
4. Que o `flutter analyze` está limpo (excepto avisos pré-existentes).
5. Se há alguma tabela `pedidos_ajuda` ou `sugestoes` já criada no Supabase (não devia haver — se houver, avisa).

Devolve o inventário e o plano de ficheiros a tocar. **Não avanças sem confirmação**.

---

## Fase 2 — Design tokens em código

Actualiza `lib/core/app_colors.dart` para conter todas as cores da tabela em `docs/design/tokens.md` (paleta base + escalas 50/100/200/500/700/900 + neutros). Nomes tal como no ficheiro.

Actualiza `lib/core/app_theme.dart`:

- `ColorScheme.fromSeed(seedColor: azul500, primary: azul500, surface: white)`.
- `AppBarTheme`: `backgroundColor: azul900` (novo tom, `#1F5F87`), `foregroundColor: white`, `elevation: 0`.
- `CardThemeData`: `elevation: 1`, `margin: EdgeInsets.zero`, `shape: RoundedRectangleBorder(BorderRadius.circular(12))`, `color: white`.
- Adiciona um `TextTheme` com a escala do `tokens.md` (display, h1, h2, body, body-strong, label, caption, mono). Fonte Roboto (default).
- Constantes de espaçamento (`AppSpacing.md = 12`, etc) em novo `lib/core/app_spacing.dart`.
- Constantes de raio (`AppRadius.md = 12`) em `lib/core/app_radius.dart`.

---

## Fase 3 — Componentes reutilizáveis

Cria em `lib/core/widgets/`:

- `wi_card.dart` — Card wrapper com padding 16, raio 12, elevation 1.
- `wi_card_destaque.dart` — fundo `azul50`, borda esquerda 4px `azul500`, elevação 2. Aceita `color` opcional para variar a cor da borda (roxo para sugestões, laranja para pedidos abertos).
- `wi_kpi_card.dart` — icon (24) + número grande (28px w500) + label (12px). Cor de fundo pastel do estado, cor de texto forte do estado.
- `wi_seccao_titulo.dart` — título 14px w500 com ícone opcional à esquerda.
- `wi_linha_kv.dart` — Row com Rótulo (width 100, `textSecondary`) + Valor (`body-strong`, opcionalmente monospace).
- `wi_badge_estado.dart` — pill pequena com cor do estado. Reforça `BadgeEstado` existente com tokens.
- `wi_chip_filtro.dart` — chip pill de filtro. Estado activo: fundo `azul100` + borda `azul500` + texto `azul900`. Estado inactivo: fundo branco + borda `#9E9D9B` (100% opacidade) + texto `textSecondary`.
- `wi_empty_state.dart` — ícone grande centrado + título + mensagem + acção opcional.

**Regra:** todos usam apenas tokens do `app_colors.dart`/`app_spacing.dart`/`app_radius.dart`. Nada de valores mágicos.

---

## Fase 4 — Alterações Supabase (schema + trigger)

Cria migração(ões) em `supabase/`:

### 4.1 Coluna `localidade` em `clientes`

```sql
alter table public.clientes
  add column if not exists localidade text;
comment on column public.clientes.localidade is
  'Localidade humana da loja, preenchida pelo admin (ex: "Pinhal Novo").';
```

### 4.2 Tabela `pedidos_ajuda`

```sql
create table if not exists public.pedidos_ajuda (
  id            uuid primary key default gen_random_uuid(),
  machine_id    text not null,
  nif           text,
  cliente_id    uuid references public.clientes(id) on delete set null,
  criado_em     timestamptz not null default now(),
  resolvido_em  timestamptz,
  notas         text
);

create index if not exists pedidos_ajuda_abertos_idx
  on public.pedidos_ajuda (criado_em desc) where resolvido_em is null;

alter table public.pedidos_ajuda enable row level security;

-- POS insere (anon) só o seu próprio pedido. Admin (authenticated) lê e atualiza.
create policy pedidos_ajuda_insert_anon on public.pedidos_ajuda
  for insert to anon with check (true);
create policy pedidos_ajuda_admin_read on public.pedidos_ajuda
  for select to authenticated using (true);
create policy pedidos_ajuda_admin_update on public.pedidos_ajuda
  for update to authenticated using (true);
```

### 4.3 Tabela `sugestoes`

```sql
create table if not exists public.sugestoes (
  id            uuid primary key default gen_random_uuid(),
  machine_id    text,
  nif           text,
  cliente_id    uuid references public.clientes(id) on delete set null,
  texto         text not null,
  criado_em     timestamptz not null default now(),
  lida          boolean not null default false,
  marcada       boolean not null default false,
  arquivada     boolean not null default false
);

create index if not exists sugestoes_por_ler_idx
  on public.sugestoes (criado_em desc) where lida = false and arquivada = false;

alter table public.sugestoes enable row level security;

create policy sugestoes_insert_anon on public.sugestoes
  for insert to anon with check (true);
create policy sugestoes_admin_read on public.sugestoes
  for select to authenticated using (true);
create policy sugestoes_admin_update on public.sugestoes
  for update to authenticated using (true);
```

### 4.4 Trigger de retenção dos pings (120 por máquina)

```sql
create or replace function public.limitar_pings_por_maquina()
returns trigger language plpgsql security definer as $$
begin
  delete from public.pings
  where machine_id = new.machine_id
    and id not in (
      select id from public.pings
      where machine_id = new.machine_id
      order by created_at desc
      limit 120
    );
  return new;
end;
$$;

drop trigger if exists trg_limitar_pings on public.pings;
create trigger trg_limitar_pings
after insert on public.pings
for each row execute function public.limitar_pings_por_maquina();
```

Cria repositórios em `lib/repositories/`:

- `pedidos_ajuda_repository.dart` — `listarAbertos()`, `listarHistorico()`, `marcarResolvido(id)`.
- `sugestoes_repository.dart` — `listarPorLer()`, `listarArquivo()`, `marcarLida(id)`, `marcarMarcada(id, valor)`, `arquivar(id)`.

Model files em `lib/models/`: `pedido_ajuda.dart`, `sugestao.dart`.

---

## Fase 5 — Regras de exibição

Cria helpers em `lib/core/exibicao.dart`:

- `String nomeExibicao(Licenca l, {int? ordemTerminal, int? totalTerminaisCliente})` — devolve:
  - Se `totalTerminaisCliente == null || totalTerminaisCliente <= 1` → só `nome do cliente` (ou `NIF X` se sem cliente).
  - Se `>= 2` → `nome do cliente · T<ordem>`.
- `String sinalLocalidade(Ping p, Cliente? c)` — devolve `"<pings.cidade ?? "?"> − <clientes.localidade ?? "-">"`.
- `IconData iconeSinal(String metodoGeo)` — mapeia:
  - `gps` → `Icons.gps_fixed` (ou equivalente Tabler-like)
  - `ip` → `Icons.wifi`
  - `nenhum` → `Icons.signal_wifi_off`
- `Color corSinal(String metodoGeo)` — verde600, laranja700, cinza terciário respectivamente.

**Cálculo da ordem do terminal:** faz-se no cliente Dart depois de buscar as licenças. Agrupa por `cliente_id`, ordena por `created_at` ascendente, atribui `1..N`. Guarda um `Map<licencaId, (ordem, total)>` reutilizável.

---

## Fase 6 — Refactor dos ecrãs existentes

Aplica os mockups combinados (descrições abaixo). **Não inventes elementos que não estejam listados.** Se algum elemento actual não está descrito, mantém-no com os tokens novos.

### 6.1 Dashboard (`lib/features/dashboard/dashboard_screen.dart`)

- **AppBar** custom (não default Material): fundo `azul900`, altura 56.
  - Esquerda: ícone `wash-machine`-like + "WashInvoice" (16px w500) + "CONTROL" (12px, opacity 0.7, letter-spacing 2).
  - Direita: ícones `refresh`, `info-circle`, `logout` — 20px, opacidade 0.9, gap 14.
- **KPIs** — Row com 4 `WiKpiCard` (Activas / A expirar / Expiradas / Pendentes), gap 6. Labels normalizadas — remove "(≤15d)". Ícones: `check-circle`, `alert-triangle`, `x-circle`, `pending-actions`.
- **Início de actividade** — só aparece se lista > 0. Título "Início de actividade ({N})". Cards são `WiCardDestaque` (fundo azul50 + borda azul), mostrando `NIF {nif}` (o `pings.nif` — nesta altura ainda não há cliente), metadata "Localidade · v{versao} · há {tempo}", e botão pill "Ativar" à direita.
- **Pedidos de ajuda** — só aparece se abertos > 0. Título "Pedidos de ajuda ({N})" + chevron. Máximo 2 cards inline, restantes em "Ver todos". Cards `WiCardDestaque(color: laranja500)`. Ícone `help-circle-filled` laranja. Nome + Sinal−Localidade + tempo + telefone. Tap no ícone `phone` liga; tap no card abre ecrã completo.
- **Actividade recente** — título com chevron. Card branco único (raio 12) com 5 linhas separadas por hairline. Cada linha: dot verde/cinza + "nome · T<n> se ≥2" + localidade humana + badge versão + tempo.
- **Rodapé pequeno** — 11px, cinza terciário: "WashInvoice Control · v1.4.0 · cesarmendes78@gmail.com".
- **Bottom nav** — 3 tabs (Dashboard/Instalações/Mapa) mantém-se.

### 6.2 Instalações (`lib/features/instalacoes/instalacoes_screen.dart`)

- **AppBar** azul900 com título "Instalações" + ícones acções.
- **SearchBar** branca com raio 12, ícone lupa cinza.
- **Chips de filtro** horizontais scroll: Activas (activo por defeito, `WiChipFiltro` estado activo), Todas versões, Todas localidades, Sem ping há…. Corrige a opacidade da borda inactiva (100%, não 40%).
- **Lista** — `ListView.separated` gap 8. Cada card:
  - Barra vertical colorida esquerda 8×32 (estado da licença).
  - Linha 1: nome cliente + T<n> se ≥2 (14px w500).
  - Linha 2: plano + validade / "expira em X dias" / "expirada há X" (11px `textSecondary`).
  - Linha 3: ícone sinal + "Sinal − Localidade" + " · há X" (11px `textTertiary`).
  - Direita: badge versão colorida + chevron.
  - Card com opacidade 0.75 quando estado é expirada.

### 6.3 DetalheCliente (`lib/features/instalacoes/detalhe_cliente_screen.dart`)

- **AppBar** azul900: chevron voltar + coluna com [Nome cliente (16px w500)] + [subtítulo "Terminal {ordem} de {total}" ou "Terminal único" — 11px opacity 0.7] + badge de estado à direita.
- **Card "Licença"** com ícone `file-certificate`: NIF, Plano, Validade (com "faltam X dias"), Série, Máquina (mono truncado + ícone copiar que faz Clipboard).
- **Card "Último acesso"** com ícone `broadcast`: Quando, Sinal (ícone + "GPS/Maps/Fornecedor internet"), Sinal diz (cidade do ping), Loja (localidade humana), Versão POS (com "actual: v{X}" se desactualizada).
- **Card "Termos aceites"** com ícone `shield-check` verde: Data, Versão, Localidade.
- **Botão "Renovar licença"** verde grande. Só se estado for aExpirar ou expirada, senão substituir por "Renovar antecipadamente" (mesma cor mas mais discreto).
- **Botão "Suspender/Reactivar licença"** outlined vermelho/verde consoante estado.
- **Histórico de acessos** — título 14px w500. Card branco único com 5 linhas: dot verde/cinza + "Localidade · v{X}" + tempo. Última linha: "Ver todos os acessos" a azul (leva a modal com 120 pings).

### 6.4 Sobre / Sistema (`lib/features/sobre/sobre_screen.dart`)

- **AppBar** simples azul900 "Sobre / Sistema".
- **Bloco identidade centrado**: ícone `wash-machine` num "chip" 56×56 azul500 raio 16, "WashInvoice Control" 18px w500, tagline "GESTOR DE LICENÇAS" 11px letter-spacing 1 `textTertiary`.
- **Cards** com título + ícone:
  - **Aplicação** (`info-circle`): Versão "1.4.0 (build N)", Pacote (mono 11px).
  - **Contactos** (`address-book`): Nome, Email azul (clicável mailto), Telefone azul (clicável tel).
  - **Supabase** (`database`): Projeto (mono), Estado (`check-circle-filled` verde + "Ligado").
  - **Sessão** (`user`): Utilizador, Último ping.
  - **Notificações push** (`bell`): Estado (Registado/Sem token), Token (mono 11px, primeiros 12 chars + …).
- **Botão "Terminar sessão"** — outlined vermelho.
- **Rodapé pequeno** — "WashInvoice · {ano actual}".

### 6.5 Login (`lib/features/auth/login_screen.dart`)

- **Scaffold background** `azul900` (não `azul500`).
- **Bloco identidade** centrado no topo (offset ~30% da altura): ícone `wash-machine` num container 72×72 `rgba(255,255,255,0.12)` raio 20, "WashInvoice" 26px w500 branco, "CONTROL" 13px letter-spacing 3 `white@0.7`.
- **Card branco** raio 16 padding 24, com:
  - Título "Acesso restrito" 15px w500.
  - Label "EMAIL" 11px w500 `textSecondary`, TextField raio 12.
  - Label "PALAVRA-PASSE" idem, TextField com ícone `eye` toggle.
  - Botão "Entrar" background `azul700` (WCAG AA sobre branco), raio 12, com seta.
- **Versão** no fundo: "v1.4.0" 11px `white@0.5`.

### 6.6 Mapa (`lib/features/mapa/mapa_screen.dart`)

- AppBar azul900 "Mapa".
- Mantém `GoogleMap` full-body.
- Markers custom: 4 assets PNG em `assets/markers/` (`activa.png`, `a_expirar.png`, `expirada.png`, `suspensa.png`), cada um 96×96, cor da paleta correspondente. Se não tiveres tempo/ferramenta, deixa como TODO no ficheiro e usa `BitmapDescriptor.defaultMarkerWithHue()` como fallback com os hues actuais.
- InfoWindow: `title = nomeExibicao(licenca, ordem, total)`, `snippet = sinalLocalidade(ping, cliente) + " · v" + versao`.

---

## Fase 7 — Ecrãs novos (Pedidos de Ajuda, Sugestões)

### 7.1 `lib/features/pedidos_ajuda/pedidos_ajuda_screen.dart`

- **AppBar** azul900 com chevron voltar + título "Pedidos de ajuda" + subtítulo "{N} abertos".
- **Segmented toggle** pill: `Abertos ({N})` / `Histórico ({N})`. Activo: fundo `azul900` branco. Inactivo: transparente `textSecondary`.
- **Modo Abertos**:
  - Lista de `WiCardDestaque(color: laranja500)`.
  - Ícone `help-circle-filled` laranja 22px.
  - Nome cliente + T<n> + Sinal−Localidade + "há {tempo} · {telefone}".
  - Dois botões: **Ligar** (azul filled) → `tel:` do telemóvel do cliente; **Resolvido** (verde filled) → UPDATE `resolvido_em = now()`.
- **Modo Histórico**:
  - Header pequeno "Histórico · {N} resolvidos".
  - Cards compactos (1 linha): `check-circle-filled` verde + nome + T<n> + "Resolvido {tempo} · duração {duracao}" + chevron. Tap abre modal com detalhes.

### 7.2 `lib/features/sugestoes/sugestoes_screen.dart`

- **AppBar** azul900 com chevron + título "Sugestões" + subtítulo "{N} por ler · {M} marcadas".
- **Segmented toggle** pill: `Por ler ({N})` / `Arquivo ({N})`.
- **Modo Por ler**:
  - Cards `WiCardDestaque(color: roxo500)`.
  - Ícone `bulb-filled` roxo 22px.
  - Linha nome cliente + T<n> à esquerda, "há {tempo}" à direita.
  - Texto da sugestão em body 13px line-height 1.5 (pode ser vários parágrafos).
  - Dois botões: **Marcar** (outlined laranja + ícone estrela) → toggle `marcada`; **Arquivar** (outlined cinza + ícone archive) → `arquivada = true, lida = true`.
- **Modo Arquivo**:
  - Cards compactos: ícone `star-filled` laranja (se marcada) ou `archive` cinza (se só arquivada) + nome + preview do texto (ellipsis) + chevron. Tap abre modal com sugestão completa.

### 7.3 Ligações a partir do Dashboard

O Dashboard já tem as secções "Pedidos de ajuda" e (opcionalmente) "Sugestões" resumidas. Tap na secção ou no chevron leva ao ecrã dedicado via `MaterialPageRoute`.

---

## Fase 8 — Bump de versão

Em `pubspec.yaml`: `version: 1.4.0+14` (patch e build number à tua escolha, sensato). Actualiza o ecrã Sobre/Sistema e rodapé do Dashboard para lerem a versão via `PackageInfo`.

---

## Fase 9 — Testes

Adiciona/actualiza:

- `test/exibicao_test.dart` — testa `nomeExibicao` (com/sem cliente, com/sem terminais múltiplos) e `sinalLocalidade` (com/sem ping/localidade).
- `test/pedidos_ajuda_test.dart` — model + repo (marcar resolvido inverte estado).
- `test/sugestoes_test.dart` — model + repo (marcar lida, marcada, arquivada).
- Ajusta testes existentes que verifiquem strings antigas ("A expirar (≤15d)" já não existe, "Máquina 8a0f8c93…" em vez de hash completo).

Corre `flutter test`. Se ficar sem output >90s, reporta antes de assumir verde.
Corre `flutter analyze`. Zero avisos novos.

---

## Fase 10 — Verificação UI real (obrigatória)

Compila APK release (`flutter build apk --release`), instala no telemóvel do Cesar (desinstala versão anterior primeiro), e corre este checklist. Regista em `docs/verificacao_apk_r1_4.md`:

1. **Login** com identidade nova, botão "Entrar" em azul-700, contraste correcto.
2. **Dashboard**:
   - AppBar azul-900 com wordmark identificado.
   - 4 KPI cards alinhados em linha, sem partir "A expirar".
   - Início de actividade com fundo azul-pálido + borda esquerda azul.
   - Pedidos de ajuda com borda esquerda laranja (se houver dados demo).
   - Actividade recente com 4-5 linhas.
   - Rodapé "WashInvoice Control · v1.4.0 · …".
3. **Instalações**:
   - Cards com barra vertical colorida + nome cliente + T<n> só quando ≥2.
   - Ícone de sinal (GPS/wifi/off) ao lado da linha "Sinal − Localidade".
4. **DetalheCliente**:
   - 3 cards com ícones semânticos.
   - Machine ID truncado + botão copiar funciona.
   - Sinal diz vs Loja em linhas separadas.
5. **Pedidos de Ajuda**:
   - Toggle Abertos/Histórico alterna.
   - Botão Ligar abre app de telefone com número certo.
   - Botão Resolvido move o pedido para histórico.
6. **Sugestões**:
   - Toggle Por ler/Arquivo alterna.
   - Marcar toggla estrela laranja.
   - Arquivar move para arquivo.
7. **Sobre / Sistema**:
   - Bloco identidade no topo com "GESTOR DE LICENÇAS".
   - Versão 1.4.0.
   - Contactos com email e telefone clicáveis (abrem app email / app telefone).
8. **Mapa** — abre sem crash. Markers coloridos (se assets prontos) ou hues nativos como fallback.

Só depois de tudo isto verificado é que a ronda fecha. **Não faças merge para `master` até o Cesar dar OK.**

---

## Fase 11 — Reconciliação da documentação (obrigatória)

No fim da implementação, antes de reportares "está feito", faz **auditoria honesta** do que ficou vs o que estava planeado:

1. Percorre este prompt secção a secção. Para cada item, confirma se:
   - Foi implementado exactamente como descrito → OK.
   - Foi implementado com adaptação (ex: usaste um widget diferente porque o proposto não fazia sentido) → **anota a adaptação e a razão**.
   - Foi adiado / deixado como TODO → **anota que ficou por fazer e porquê**.
   - Foi impossível (ex: dependência em falta, decisão do Cesar contradiz) → **anota o bloqueio**.

2. Actualiza `docs/design/prompt_code_redesign_v1_4.md` acrescentando uma secção final `## Reconciliação — o que ficou vs planeado (após implementação)` com esse mapa item-a-item. Não apagues o texto original — deixa o histórico da intenção, e regista a realidade em baixo.

3. Actualiza `docs/estado_e_roadmap.md`:
   - Adiciona a ronda 1.4.0 à secção "O que foi entregue".
   - Move para "Curto prazo" (ou reclassifica) tudo o que ficou por fazer.
   - Actualiza a data no cabeçalho.

4. Se qualquer decisão arquitectural mudou durante a implementação (ex: escolheste guardar `distrito` em `pings` também porque foi mais barato do que separado), regista em "Decisões arquitecturais tomadas" do `estado_e_roadmap.md` com o "porquê".

**Regra dourada:** a documentação nunca pode mentir sobre o estado real. Se o código diz uma coisa e o `.md` diz outra, o `.md` está errado — corrige-o.

---

## NÃO TOCAR EM

- **Nada do POS Windows** — só afecta o Control. As tabelas novas (`pedidos_ajuda`, `sugestoes`) e a coluna `localidade` recebem INSERTs anon dos POS quando essa integração for feita **numa ronda futura no repo do POS**, não nesta.
- **Edge Function `enviar-push`** — está a funcionar. Não mexer.
- **Edge Function `assinar-documento`** — do POS. Não mexer.
- **`lib/services/fcm_service.dart` e `fcm_background_handler.dart`** — funcionam. Não mexer.
- **`lib/services/licenca_assinatura.dart`** — HMAC do POS. Fica para ronda pós-AT.
- **`supabase/rls_policies.sql`** — reconciliação Opção A/D fica pós-AT.
- **Router / navegação principal** — só adicionar rotas para os ecrãs novos.
- **`lib/core/config.dart`** — contactos e URLs. Não mexer.
- **README.md** — actualiza só a secção "Estado" com versão 1.4.0 e menção às novas features; não reescreveres do zero.

---

## Regras

- Português europeu em toda a UI (ecrã, faturar, gravar, atualizar, arquivar, palavra-passe — nunca brasileirismos).
- Nada de valores mágicos: cores, espaçamentos, raios só através dos tokens.
- Se um mockup e o código actual entrarem em conflito com o `tokens.md`, o `tokens.md` ganha.
- Se algum item deste prompt não fizer sentido face ao código real que encontras, para e reporta antes de improvisar.

---

## Ordem de commits sugerida

1. `tokens: paleta + tipografia + espaçamentos + raios`
2. `widgets: WiCard, WiCardDestaque, WiKpiCard, WiChipFiltro, WiEmptyState`
3. `helpers: exibicao (nomeExibicao, sinalLocalidade, iconeSinal)`
4. `supabase: coluna localidade em clientes + trigger retention pings`
5. `supabase: tabelas pedidos_ajuda + sugestoes + policies + índices`
6. `dashboard: refactor visual (P1..P6 corrigidos)`
7. `instalacoes: refactor com filtros afinados`
8. `detalhe_cliente: cards com sinal-localidade separados`
9. `sobre: identidade + secção FCM tokenizada`
10. `login: azul900 + wordmark`
11. `pedidos_ajuda: novo ecrã com toggle abertos/historico`
12. `sugestoes: novo ecrã com toggle por-ler/arquivo`
13. `mapa: markers custom (ou TODO se falhar)`
14. `version: bump 1.4.0`
15. `test: exibicao + repositories novos`
16. `docs: verificacao_apk_r1_4.md em branco`

Reporta SHA de cada commit no fim. Não faças merge até validação UI real do Cesar.

---

## Reconciliação — o que ficou vs planeado (após implementação)

> Auditoria honesta pós-implementação (Fase 11). O texto acima é a **intenção**;
> isto é a **realidade**. Onde divergem, isto manda.

### Decisões tomadas com o Cesar antes de começar (Fase 1)
- **Branch:** a árvore estava suja (FCM + tokens parciais por commitar) na
  `feature/melhorias-r1-r2`. Fez-se um commit de arrumação e criou-se
  `feature/redesign-visual` a partir daí. `google-services.json` passou a
  ignorado (era um segredo por versionar).
- **`azul900`:** o prompt pedia `#1F5F87`; o `tokens.md` tinha `#185277`.
  Escolhido **`#1F5F87`** e `tokens.md` §1.2/§1.3 reconciliado (a fonte de
  verdade não pode mentir).
- **Migrações Supabase:** aplicadas **em produção** (projeto
  `oefqbkhioncakojipqyx`) via MCP, com autorização explícita — incluindo o
  trigger destrutivo de retenção de pings.

### Implementado como descrito → OK
- Fase 2 tokens (paleta 50/100/200/500/700/900, tipografia, `AppSpacing`,
  `AppRadius`, tema).
- Fase 3 os 8 componentes `Wi*`.
- Fase 4 as 4 migrações + `Cliente.localidade` + models/repos/providers.
- Fase 5 helpers de exibição (nomeExibicao, sinalLocalidade, iconeSinal, ordem).
- Fase 6.1–6.5 e 7.1/7.2 ecrãs, Fase 8 bump, Fase 9 testes (43 verdes),
  Fase 10 checklist criada.

### Implementado com adaptação (e porquê)
- **`WiCardDestaque`:** o prompt dizia "fundo azul50 fixo, só a borda varia".
  Fez-se o fundo **derivar do acento** (`tom50`), senão laranja/roxo com fundo
  azul ficava incoerente. Continua azul por defeito.
- **`corSinal(gps)`:** prompt pedia `verde600`; o `tokens.md` não tem 600 →
  usou-se `verde700` (token mais próximo, sem valor mágico).
- **`AppSpacing`:** escala nomeada (`xs..xxxl`) em vez de só `md=12` — cobre a
  escala 4px inteira do `tokens.md` §3.
- **Dashboard:** mantidas as secções **"A expirar"** e **"Pedidos de renovação"**
  (existiam, não estavam descritas → regra "manter com tokens novos"),
  restilizadas. Adicionada secção **"Sugestões"** resumida para o ecrã de
  sugestões ser alcançável (6.1 não a detalhava; tokens.md §9 e 7.3 pedem-na).
- **DetalheCliente:** mantido o botão **"Confirmar pagamento e gerar licença"**
  (lógica de negócio essencial, não descrita no prompt) — posto a **azul** para
  não colidir com o verde "Renovar". "Renovar antecipadamente" é a variante
  discreta quando a licença não está a expirar.
- **Sobre:** removida a linha "URL" (o 6.4 só pede Projeto + Estado "Ligado").
- **Instalações:** filtro por defeito passou a **"Activas"** (pedido explícito),
  alterando o comportamento anterior ("mostrar todas").

### Adiado / TODO
- **Fase 6.6 markers custom:** os 4 PNG 96×96 em `assets/markers/` **não** foram
  criados (sem ferramenta de geração de imagem no fluxo). Fica **TODO explícito**
  no `mapa_screen.dart`; usa-se `defaultMarkerWithHue` com os hues por estado.
- **Fase 10 verificação UI real:** o APK release / instalação no telemóvel é do
  Cesar — `docs/verificacao_apk_r1_4.md` está pronto, por correr.
- **Chevron "Actividade recente":** decorativo (o prompt não deu destino).

### Não tocado (conforme "NÃO TOCAR EM")
POS, edge functions, `fcm_service`/`fcm_background_handler`,
`licenca_assinatura`, `rls_policies.sql`, `config.dart`, navegação principal
(`home_shell` — bottom nav mantém 3 tabs). Novos ecrãs abrem por
`MaterialPageRoute`, sem mexer no router.
