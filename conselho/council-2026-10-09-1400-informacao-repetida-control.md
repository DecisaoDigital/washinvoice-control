# Council técnico — informação repetida no Control (2026-10-09)
Modo técnico (4 conselheiros Claude isolados, sonnet), SEM revisão cruzada (as quatro posições convergiram). Só análise; nenhum código alterado.

Pergunta do César: «o control deverá ser revisionado, talvez pelo council, porque tem informação repetida em todo o lado».
Não informado: que ecrãs o César usa; o que ele vê como «repetido»; sem métricas de uso.

## Posições
- **Arquitecto (média-alta):** Agora (agora_providers.dart:35-89) e Dashboard (dashboard_screen.dart:121-142) carregam as mesmas fontes de forma independente. Um só provider partilhado (nome sugerido `controloProvider`) filtrado por appFilterProvider; ecrãs = vistas; selector e envelope na casca (home_shell). Cuidado: home_shell empurra filtro por destinoPushProvider/agoraTipoFiltroProvider (mexe nas notificações); dashboardRefreshProvider e agoraRefreshProvider são dois mecanismos de refresh para os mesmos dados; reutilizar fistPendentesProvider. Partir ficheiros grandes pode esperar.
- **Céptico (média):** «repetido» mistura 3 problemas (dados, UI, código). O bug está nas fontes (dashboard:133 faz o seu próprio pedidosRepo.pendentes; agora_providers:43 faz o mesmo; fist_pendentes_provider é outra via). Fundir ecrãs antes de unificar providers só muda a divergência de sítio; apagar o Resumo sem saber se é o único com KPIs perde funcionalidade em silêncio. Recomenda uma semana de log de aberturas antes de decidir sobre o Resumo.
- **Pragmático (média):** fase 1 (≤2 h): tirar o envelope do Resumo e ligar contagens ao provider único; teste: Agora, Mais e Resumo mostram o mesmo número em 3 casos no Redmi. Fase 2 (≤1 dia): Resumo perde listas de urgência, selector global. Fase 3 só a pedido: eliminar/fundir o Resumo. Primeiro passo: lista de 10 linhas dos blocos do Resumo que já existem em Agora.
- **Investigador (média):** WiAppSelector já é widget partilhado, montado em 6 AppBars (agora:200, pedidos_ajuda:118, sugestoes:105, mapa:121, dashboard:311, instalacoes:393); envelope montado em agora:199 e dashboard:260; repositórios (11, um por tabela) estão limpos. Opções: A fundir Resumo no Agora; B alimentar o Resumo do agoraProvider; C selector no shell (ecrãs profundos ficam sem selector local). Ordem: B, envelope só no Agora, C, e só depois A.

## Convergência
Unanimidade: a repetição que dói são as fontes de dados (contagens calculadas em 2-3 sítios) e o «chrome» (selector, envelope), não o número de ecrãs; unificar isso primeiro; não apagar o Resumo nem partir ficheiros grandes já.

## Nota do presidente
Inventário do agente explore (repetição entre ecrãs, textos, widgets) ainda não tinha chegado quando se fechou o veredicto.

## Inventário do agente explore (chegou depois do veredicto; leitura por excertos)
- **Fetch repetido:** o trio clientes+licenças+pings é lido inline em 12 ecrãs e `ContextoInstalacoes.build` chamado em ~12 sítios. A query «renovações pendentes» está em dashboard:133, agora_providers:43 e instalacoes_por_estado:89. Pesquisa global e sugestoes/detalhe não passam `app` (divergem dos outros). O comentário em agora_providers:28-31 («compõe, não consulta de novo») não corresponde ao código.
- **Cartões:** 5 cartões de licença (dashboard `_CardLicenca`, instalacoes `_CartaoInstalacao`, por_estado `_CardLic`, detalhe_cliente `_CardLicenca`, agora `_Cartao`); 3 cartões de pedido de ajuda (dashboard, pedidos_ajuda, agora); 4 badges de estado (`BadgeEstado`, `WiBadgeEstado`, `ChipEstado` sem usos, `_ChipLicenca`, `_Pill`); `ChipTier` duplica `WiTierBadge`.
- **Suspender/Reactivar/Dar dias:** 3 UIs para a mesma acção (instalacoes_screen:205-299, detalhe_cliente:340-397, controlo_remoto_widgets) com mensagens iguais e textos de «dias» que divergem; `suspender`/`reactivar` @Deprecated em licencas_repository sem usos aparentes.
- **Regras e rótulos:** «a expirar = 15 dias» em 3 sítios; rótulos de estado em 4; frase «expirou/expira + data» copiada; «localidade senão cidade» copiada 4×; `'v${versao ?? '?'}'` 4×; diálogo «Voltar + botão vermelho» escrito à mão em ≥6 sítios; mensagens de lista vazia sem helper (existe WiEmptyState).
- **Seletor de app:** `WiAppSelector` na AppBar E `WiComPastilhaApp` no corpo, nos mesmos 6 ecrãs, por isso o filtro activo aparece duas vezes no mesmo ecrã; boilerplate `ref.listen(appFilterProvider…)` em 4 ecrãs.
- **Bem feito:** pedidosSitePorVerProvider, fistPendentesProvider, WiAppBadgeAuto, renovar_licenca.dart, resolver_pedido_ajuda.dart.
