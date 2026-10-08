import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../models/actualizacao_info.dart';
import '../../repositories/providers.dart';
import '../../services/push_routing.dart';
import '../acessos/gestao_acessos_screen.dart';
import '../acessos/punho/fist_pendentes_provider.dart';
import '../acessos/punho/punho_pedidos_screen.dart';
import '../actualizacao/banner_actualizacao.dart';
import '../agora/agora_modelo.dart';
import '../agora/agora_providers.dart';
import '../agora/agora_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../instalacoes/instalacoes_screen.dart';
import 'mais_screen.dart';

/// A casca da app: três separadores por **acção**, e não por entidade.
///
/// «Agora» (a fila do que está à espera) · «Clientes» (as instalações) ·
/// «Mais» (Resumo, Pedidos Fist, Acessos, Mapa, Sugestões, Pedidos de ajuda,
/// Sobre). Decisão do Council de 8/10/2026.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, @visibleForTesting this.paginasParaTeste});

  /// Só para testes: páginas de substituição (por ex. um stub no lugar de
  /// «Clientes», que precisa do Supabase). Em produção é sempre [paginas].
  final List<Widget>? paginasParaTeste;

  /// Posição de cada separador. Os índices vivem num sítio só: o push routing e
  /// a barra usam estes nomes, não números soltos.
  static const indiceAgora = 0;
  static const indiceClientes = 1;
  static const indiceMais = 2;

  /// As páginas da barra, na ordem dos separadores.
  ///
  /// Anda **sempre** a par de [itens]: mesma ordem, mesmo comprimento. Quando
  /// não andou (cinco páginas, quatro botões), o `BottomNavigationBar` atirou
  /// `RangeError` a cada frame e a app ficou pintada mas morta — Redmi,
  /// 5/8/2026. Há um teste sobre este invariante.
  static const paginas = <Widget>[
    AgoraScreen(),
    InstalacoesScreen(),
    MaisScreen(),
  ];

  /// Os separadores da barra de baixo, com badge numérico quando há pendentes.
  ///
  /// [agora]: total de itens na fila. [maisFist]: pedidos Fist pendentes (0 para
  /// quem não é admin global, que nem os vê).
  static List<BottomNavigationBarItem> itens({int agora = 0, int maisFist = 0}) =>
      [
        BottomNavigationBarItem(
          icon: _comBadge(const Icon(Icons.bolt), agora),
          label: 'Agora',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.devices),
          label: 'Clientes',
        ),
        BottomNavigationBarItem(
          icon: _comBadge(const Icon(Icons.more_horiz), maisFist),
          label: 'Mais',
        ),
      ];

  static Widget _comBadge(Widget icone, int n) => n <= 0
      ? icone
      : Badge(label: Text('$n'), child: icone);

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = HomeShell.indiceAgora;

  List<Widget> get _paginas =>
      widget.paginasParaTeste ?? HomeShell.paginas;
  bool _modalObrigatorioAberto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Se a verificação terminou antes deste ecrã montar, o provider já pode
    // trazer uma actualização obrigatória — o `ref.listen` do build não a
    // apanharia (só reage a mudanças). Verificamos o estado inicial à mão.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _talvezModalObrigatorio(ref.read(actualizacaoDisponivelProvider));
      // Push tocado com a app fechada: `getInitialMessage()` já resolveu e
      // escreveu o destino enquanto estávamos no splash, portanto o
      // `ref.listen` do build (que só reage a mudanças) nunca o veria.
      _talvezIrParaDestinoDoPush(ref.read(destinoPushProvider));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Voltar à app: a contagem de pedidos Fist (badge) pode ter mudado.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(fistPendentesProvider);
    }
  }

  /// Executa o destino trazido por um push e limpa-o, para o mesmo toque não
  /// voltar a navegar num rebuild seguinte.
  ///
  /// Fecha primeiro o que estiver aberto por cima dos separadores: um ecrã de
  /// detalhe esquecido taparia o destino. Os índices passam por [_seleccionar],
  /// que os valida.
  void _talvezIrParaDestinoDoPush(DestinoPush? destino) {
    if (destino == null || !mounted) return;
    ref.read(destinoPushProvider.notifier).state = null;
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);

    switch (destino) {
      case DestinoPush.agoraTerminalNovo:
        ref.read(agoraTipoFiltroProvider.notifier).state =
            TipoAgora.terminalNovo;
        _seleccionar(HomeShell.indiceAgora);
      case DestinoPush.agoraAjuda:
        ref.read(agoraTipoFiltroProvider.notifier).state = TipoAgora.ajuda;
        _seleccionar(HomeShell.indiceAgora);
      case DestinoPush.pedidosFist:
        // «Pedidos Fist» é só do admin global. Sem isso não há nada para
        // mostrar: fica na fila «Agora» em vez de bater num erro.
        final admin = ref.read(souAdminGlobalProvider).valueOrNull ?? false;
        if (!admin) {
          _seleccionar(HomeShell.indiceAgora);
          return;
        }
        _seleccionar(HomeShell.indiceMais);
        ref.read(punhoPedidosRefreshProvider.notifier).state++;
        nav.push(MaterialPageRoute(builder: (_) => const FistPedidosScreen()));
      case DestinoPush.resumo:
        _seleccionar(HomeShell.indiceMais);
        nav.push(MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  /// Muda de separador. Um índice fora da barra nunca chega ao
  /// `BottomNavigationBar` — foi isso que o fez rebentar uma vez.
  void _seleccionar(int i) {
    if (i < 0 || i >= _paginas.length) return;
    setState(() => _index = i);
  }

  void _talvezModalObrigatorio(ActualizacaoInfo? info) {
    if (info == null || !info.obrigatoria || _modalObrigatorioAberto) return;
    if (!mounted) return;
    _modalObrigatorioAberto = true;
    mostrarModalObrigatorio(context, info).whenComplete(() {
      // Só se este widget ainda existir; o modal normalmente nunca fecha.
      _modalObrigatorioAberto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Actualização obrigatória que chegue depois do arranque → modal.
    ref.listen<ActualizacaoInfo?>(
      actualizacaoDisponivelProvider,
      (_, actual) => _talvezModalObrigatorio(actual),
    );
    // Push tocado com a app já aberta (ou em background).
    ref.listen<DestinoPush?>(
      destinoPushProvider,
      (_, actual) => _talvezIrParaDestinoDoPush(actual),
    );

    final indice = _index.clamp(0, _paginas.length - 1);

    return Scaffold(
      body: Column(
        children: [
          const BannerActualizacao(),
          Expanded(
            child: IndexedStack(index: indice, children: _paginas),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: indice,
        onTap: _seleccionar,
        selectedItemColor: AppColors.azul,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        items: HomeShell.itens(
          agora: ref.watch(agoraTotalProvider),
          maisFist: ref.watch(fistPendentesTotalProvider),
        ),
      ),
    );
  }
}
