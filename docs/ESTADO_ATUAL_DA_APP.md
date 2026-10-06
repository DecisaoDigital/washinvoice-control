# Estado actual — Control

Actualizado: 2026-08-02
Versão pubspec (branch `master`): **1.8.4+29**
Último release publicado (tag GitHub): **v1.8.4** (2026-07-29)

> Existe um estado detalhado por ronda em `docs/estado_e_roadmap.md` (544 linhas,
> histórico completo). Este ficheiro é o resumo do estado real de hoje;
> `estado_e_roadmap.md` mantém o registo cronológico.

---

## O que é o Control

App Android (Flutter + Riverpod + Supabase + Firebase Messaging) usada só pelo Cesar (admin único) para operar o parque **da Decisão Digital** — todas as apps da empresa. Primeiras duas: `pos` (WashInvoice) e `punho`.

**Não é o produto vendido.** O produto é o POS WashFactura; o Control é backoffice interno.

Marca comercial: **WashInvoice** — "WashControl" continua nome interno para distinguir do POS.

---

## O que já funciona

### Multi-app (v1.8.0)
- Coluna `app text NOT NULL` (sem default) em `licencas`, `pings`, `pedidos_ajuda`, `pedidos_renovacao`, `sugestoes`, `aceites_termos`. Linhas pré-existentes migradas para `'pos'`.
- Selector na AppBar (Dashboard, Instalações, Mapa, Pedidos de Ajuda, Sugestões): Todas | WashInvoice | Fist. Persistido em SharedPreferences (`app_filtro`).
- Dashboard com repartição por app quando o filtro está em "Todas".
- Badges `POS` (azul) e `FIST` (verde) por linha, só com filtro "Todas". Excepção: ficha do cliente e pesquisa global mostram sempre.
- Badge `PRO` (#177) antes do nome do cliente para `tier` pro e legado.
- Push routing por `data.tipo` (#211): `novo_terminal` → Instalações, `novo_pedido` → Pedidos Fist, `pedido_ajuda` → Pedidos de Ajuda, `inicio_actividade` → Dashboard.

### Separador Fist (v1.8.1 / v1.8.2)
- Aprovar, recusar e revogar pedidos de acesso ao Fist — visível só ao admin global.
- Filtros por estado: pendentes, aprovados, recusados, revogados.
- Aprovar deixa escolher empresa de destino (existente ou nova) e limite de utilizadores.
- Revogar mostra antes quem perde acesso.
- Refresh automático ao voltar à app e ao entrar no separador (não há polling).
- RPCs `punho_decidir_pedido`, `punho_listar_pedidos_admin`, `punho_listar_empresas_admin` — recusam qualquer conta que não seja admin.

### Acessos por organização — parte A (v1.8.1)
- Tabelas `organizacoes`, `pedidos_acesso`, `convites_organizacao` aplicadas em produção (migration `20260726032530`).
- Trigger de auth filtra `app in ('', 'control')` para não colidir com o do Fist.
- RPCs `meu_estado_acesso`, `decidir_pedido_acesso`, `criar_convite_organizacao`.
- Gate de sessão: ter sessão Supabase deixou de bastar para entrar — acesso é libertado à mão. Quem ainda não foi aprovado vê ecrã de estado (`AcessoPendenteScreen`) em vez da app.
- Falha a consultar estado mostra erro com retentativa, em vez de ficar preso no splash.

### Dashboard e navegação
- AppBar responsiva (task #188) — título compacto <600 dp, `WiAppSelector` com pastilha própria, hit-target 48×48.
- 4 separadores base + 1 exclusivo do admin: Dashboard, Instalações, Mapa, Acessos, Fist (só admin).
- KPIs clicáveis (Activas / Pendentes / A expirar / Expiradas) abrem `InstalacoesPorEstadoScreen`.
- Pesquisa global (clientes, licenças, pings, pedidos, sugestões) com debounce 250 ms.
- Filtros na Instalações (estado, versão, cidade, "sem ping há N dias") + ordenação persistida em SharedPreferences.

### Instalações — controlo remoto
- `DetalheClienteScreen` opera licenças via Edge Function `gerir-licenca` (`prolongar`, `definir_validade`, suspender, reactivar, cancelar, mudar tier).
- Autorização em duas camadas: `verify_jwt: true` + `getUser()` + `is_admin()`; anon key sozinha → 401.
- Cada acção regista duas linhas em `licencas_audit`: uma do trigger + uma explícita da function com o autor verificado.
- Card de preferências read-only com regra `featureVisivel` (Base esconde tudo).
- Nome comercial em destaque (Licenca + Cliente com `nomeComercial`); designação social na linha pequena. Cascata: comercial (cliente→licença) → designação (idem) → NIF.
- Card `Series` fiscais com modais (setup credenciais WSE + nova série).

### Comunicar séries à AT
- `comunicar-serie-pos` chama webservice AT (comunicação de séries fiscais).
- Tabela `credenciais_wse` com RLS + gate `wse_producao`/`wse_teste` no `guardar-credenciais-wse-pos`.

### Push (FCM)
- Firebase project `washinvoice-control` + service account `fcm-sender`.
- `admin_dispositivos` guarda tokens por user; cada user só toca no seu.
- Edge Function `enviar-push` gera JWT OAuth2 e chama FCM v1 API.
- Foreground: SnackBar com vibração; título prefixado com app (`[PUNHO] Novo terminal`) a partir de `data['app']`.
- Background: notificação nativa desenhada pelo SO a partir de payload `notification` — prefixo tem de vir da Edge Function `enviar-push`.
- Triggers no Postgres: `notificar_inicio_actividade` (1º ping sem licença, dedup), `notificar_pedido_ajuda`, `punho_criar_pedido_ao_registar` (via `enviar-push`).
- **Notificação de empresa nova confirmada ponta-a-ponta (02/08/2026)**: trigger `trg_notificar_novo_pedido_punho` (AFTER INSERT em `punho_pedidos_acesso`) → `enviar-push` devolveu 200 3s depois do pedido; Cesar aprovou no Control ~1min depois. Fluxo app→pedido→push→aprovação→`punho_membros` activo, verificado sem intercorrências.

### Auto-update do Control (#100 / v1.7.0)
- Tabela `versoes_apps` (`build_number`, `url_download`, `obrigatoria`).
- Edge `versao-mais-recente` reutilizável pelo POS.
- Timer de verificação 6h → 24h alinhado com POS (#119).
- Botão on-demand "Verificar actualização" no ecrã Sobre.
- Banner amarelo (voluntária) / modal bloqueante (obrigatória).
- `Dates.data`/`Dates.dataHora` fazem `.toLocal()` (#101).

### Backup
- Ecrã de exportação CSV/ZIP em Sobre/Sistema → "Exportar dados" (`core/csv.dart` UTF-8+BOM; `archive` para ZIP; `share_plus`).

### Testes
- **232 testes verdes** (v1.8.2), `flutter analyze` sem avisos novos.

---

## O que está a meio (WIP)

- **Parte B de `acessos_organizacoes`** (task **#190**) — coluna `organizacao_id` nas 5 tabelas de negócio + substituir policies. O SQL original assumia `licencas.user_id` que nunca existiu em prod. Reescrever contra modelo real **antes** de aprovar primeiro não-admin no separador Acessos.
- Merge `feat/aprovar-pedidos-punho` → `main` — branch existe localmente (3 commits à frente de `feature/multi-app-e-badge-pro`); no `master` já está a v1.8.2 mas há branch órfãs por arrumar.
- Line endings CRLF/LF a poluir `git status` — dezenas de ficheiros "modified" sem conteúdo real diff. Arrumação futura.
- **`supabase/punho_campainha_tempo_real.sql` por commitar** (untracked desde 02/08/2026) — contém o trigger de campainha que **não** está em uso: o Fist usa broadcast por canal público porque `realtime.messages` deste projecto não tem partições (Realtime recusa com `MissingPartition`; criar partições exige permissões de schema `realtime` que não temos).
- **Limite de colaboradores do Fist não é respeitado pela app** — `punho_subscricoes.limite_colaboradores_ativos` é atribuído pelo Control, mas a app usa o número declarado pelo gestor no onboarding. Por decidir se a app passa a obedecer ao servidor.

---

## O que ainda não existe

- Tabela `admins` (`is_admin()` cria a função mas não a tabela — ficará quando aplicar RLS Opção A/D pós-AT).
- Fechar RLS público na base (Opção D preparada em `supabase/rls_policies.sql`, não aplicada).
- Nuvem para backups (fase futura — hoje só CSV/ZIP local).
- `pg_dump` automático nem PITR (Supabase Free). Backup manual JSON antes de mudanças arriscadas.

---

## Bugs conhecidos abertos

- **Contrato multi-app desactualizado**: `supabase/contrato_apps.md` cabeçalho diz "2026-07-11" e cataloga só 1 Edge Function chamada pelo POS. Realidade: POS chama 8. Ver auditoria `outputs/AUDITORIA_MD_vs_CODIGO_2026-07-29.md` §1.
- **README stale**: refere v1.4.0 + Pedidos de Ajuda como novidade. Realidade: v1.8.2 com multi-app, badge PRO, aprovar pedidos Fist, fix push destino.
- **`estado_e_roadmap.md:108`** — tabela declara POS "em desenvolvimento: 1.6.6" e "pré-certificação AT". Realidade: POS 2.2.1+41 com dossier AT enviado.

---

## Próximos passos priorizados

1. **Decidir o limite de colaboradores do Fist** — a app ignora hoje o valor atribuído pelo Control (02/08/2026).
2. **Task #190 — parte B de `acessos_organizacoes`** reescrita contra modelo real; bloqueia aprovar não-admins.
3. Actualizar `supabase/contrato_apps.md` e `README.md` (menor risco de Claude Code partir RLS por seguir contrato antigo).
4. Merge `feat/aprovar-pedidos-punho` no `main` + compilar APK 1.8.2 + testar no Redmi.
5. Aplicar Opção D de RLS (fechar anon writes) — depende de decisão pós-AT do POS.
6. Testes E2E do fluxo aprovar/recusar Fist ligado ao Fist real.

---

## Referências

- Estado + roadmap cronológico: `docs/estado_e_roadmap.md`.
- Release notes: `docs/release_notes/1.8.2.md`.
- Auditoria .md vs código: `outputs/AUDITORIA_MD_vs_CODIGO_2026-07-29.md`.
- Contrato multi-app POS ↔ Control: `supabase/contrato_apps.md` (desactualizado — ver bugs).
- Design multi-app: `docs/design/multi_app.md`.
- Design aprovação Fist: `docs/design/control_aprova_punho.md`.
- Roadmap raiz (repo pai): `../ROADMAP.md`.
- Backend Supabase: projecto `oefqbkhioncakojipqyx` (eu-central-1).
