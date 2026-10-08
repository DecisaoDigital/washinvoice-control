import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_filter/app_filter_provider.dart';
import '../../core/apps_ui.dart';
import '../../core/contexto_instalacoes.dart';
import '../../repositories/providers.dart';
import '../../repositories/punho_admin_repository.dart';
import '../acessos/punho/fist_pendentes_provider.dart';
import 'agora_modelo.dart';

/// O que a fila «Agora» mostra, já ordenado por urgência.
class AgoraData {
  final List<ItemAgora> itens;
  const AgoraData(this.itens);

  Map<TipoAgora, int> get contagem => contarPorTipo(itens);
}

/// Sinal para refazer a fila (puxar para baixo, voltar à app, push).
final agoraRefreshProvider = StateProvider<int>((_) => 0);

/// Tipo escolhido nos chips do topo; `null` = todos. Um push («novo terminal»,
/// «pedido de ajuda») escreve aqui antes de levar o Cesar ao separador.
final agoraTipoFiltroProvider = StateProvider<TipoAgora?>((_) => null);

/// A fila «Agora».
///
/// **Compõe, não consulta de novo**: usa os mesmos repositórios e métodos que o
/// Resumo (licenças, pings, pedidos de ajuda, renovações, sugestões) e o mesmo
/// provider dos Pedidos Fist ([fistPendentesProvider], só admin global). A regra
/// de «expirada» e «a expirar» é a do próprio `Licenca.estado`.
///
/// Reage ao selector de app: o filtro vai ao servidor, como nos outros ecrãs.
/// Os pedidos Fist só entram com o filtro em «Todas» ou «Fist» — são sempre Fist.
final agoraProvider = FutureProvider<AgoraData>((ref) async {
  final filtro = ref.watch(appFilterProvider);
  ref.watch(agoraRefreshProvider);
  final app = filtro.valorApp;

  final licencas = ref.read(licencasRepoProvider).listar(app: app);
  final pings = ref.read(pingsRepoProvider).ultimosPorInstalacao(app: app);
  final ajuda = ref.read(pedidosAjudaRepoProvider).listarAbertos(app: app);
  final renovacoes = ref.read(pedidosRepoProvider).pendentes(app: app);
  final sugestoes = ref.read(sugestoesRepoProvider).listarPorLer(app: app);
  final clientes = ref.read(clientesRepoProvider).listar();
  // Os nomes que o Fist já sabe dos seus terminais. Falha em silêncio, como no
  // Resumo: sem eles a cascata de nomes resolve-se na mesma.
  final nomesFist = ref
      .read(punhoAdminRepoProvider)
      .nomesPorTerminal()
      .catchError((_) => <String, NomeDoTerminalFist>{});
  // Erro aqui NÃO se engole: sem os pedidos Fist a fila mentiria («Nada
  // pendente»). Propaga-se e o ecrã mostra o erro com «Tentar de novo».
  final acessosFist = filtro.aceita(AppsUi.punho)
      ? ref.watch(fistPendentesProvider.future)
      : Future.value(<FistPedido>[]);

  final r = await (
    licencas,
    pings,
    ajuda,
    renovacoes,
    sugestoes,
    clientes,
    nomesFist,
    acessosFist,
  ).wait;

  final ctx = ContextoInstalacoes.build(
    clientes: r.$6,
    licencas: r.$1,
    pings: r.$2,
    nomesFist: r.$7,
  );
  return AgoraData(
    comporItensAgora(
      ctx: ctx,
      licencas: r.$1,
      pings: r.$2,
      // Uma licença por terminal: quem já tem linha em `licencas` não é novo.
      machineIdsComLicenca: {for (final l in r.$1) l.machineId},
      ajuda: r.$3,
      renovacoes: r.$4,
      sugestoes: r.$5,
      acessosFist: r.$8,
    ),
  );
});

/// Total de itens pendentes — o badge do separador «Agora». 0 enquanto
/// carrega ou se falhar (um badge nunca deve rebentar o ecrã).
final agoraTotalProvider = Provider<int>(
  (ref) => ref.watch(agoraProvider).valueOrNull?.itens.length ?? 0,
);
