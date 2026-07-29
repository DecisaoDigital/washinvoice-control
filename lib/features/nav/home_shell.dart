import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../models/actualizacao_info.dart';
import '../../repositories/providers.dart';
import '../../services/push_routing.dart';
import '../actualizacao/banner_actualizacao.dart';
import '../dashboard/dashboard_screen.dart';
import '../instalacoes/instalacoes_screen.dart';
import '../mapa/mapa_screen.dart';
import '../acessos/gestao_acessos_screen.dart';
import '../acessos/punho/punho_pedidos_screen.dart';
import '../pedidos_ajuda/pedidos_ajuda_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool _modalObrigatorioAberto = false;

  static const _paginas = [
    DashboardScreen(),
    InstalacoesScreen(),
    MapaScreen(),
    GestaoAcessosScreen(),
  ];

  /// "Pedidos Punho" é exclusivo do admin global — as RPCs `punho_*_admin`
  /// recusam qualquer outra conta. Um gerente de organização não vê o
  /// separador, em vez de lhe bater com um erro.
  static const _paginaPunho = PunhoPedidosScreen();

  @override
  void initState() {
    super.initState();
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

  /// Índice do separador "Punho", ou `null` se não for admin global (nesse caso
  /// o separador não existe).
  int? get _indicePunho => _admin ? _paginas.length : null;
  bool _admin = false;

  /// Executa o destino trazido por um push e limpa-o, para o mesmo toque não
  /// voltar a navegar num rebuild seguinte.
  void _talvezIrParaDestinoDoPush(DestinoPush? destino) {
    if (destino == null || !mounted) return;
    ref.read(destinoPushProvider.notifier).state = null;

    switch (destino) {
      case DestinoPush.dashboard:
        _seleccionar(0);
      case DestinoPush.instalacoes:
        _seleccionar(1);
      case DestinoPush.pedidosPunho:
        // Sem separador Punho (não é admin global) não há nada para mostrar:
        // fica no Dashboard em vez de um índice inválido.
        _seleccionar(_indicePunho ?? 0);
      case DestinoPush.pedidosAjuda:
        // Não é separador — vive por cima do Dashboard, como quando se lá
        // chega pelo card de KPI.
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PedidosAjudaScreen()),
        );
    }
  }

  /// Muda de separador. Aterrar no Punho pede sempre dados frescos: o
  /// `IndexedStack` manteve o ecrã montado desde a primeira vez.
  void _seleccionar(int i) {
    if (i == _indicePunho) {
      ref.read(punhoPedidosRefreshProvider.notifier).state++;
    }
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

    final admin = ref.watch(souAdminGlobalProvider).valueOrNull ?? false;
    // O destino de um push pode chegar fora do build, quando já não há `admin`
    // à mão — daí ficar guardado.
    _admin = admin;
    final paginas = [..._paginas, if (admin) _paginaPunho];
    // Se o separador desaparecer (perfil resolvido depois do primeiro build),
    // o índice actual pode ficar fora do intervalo.
    final indice = _index.clamp(0, paginas.length - 1);

    return Scaffold(
      body: Column(
        children: [
          const BannerActualizacao(),
          Expanded(
            child: IndexedStack(index: indice, children: paginas),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: indice,
        onTap: _seleccionar,
        selectedItemColor: AppColors.azul,
        unselectedItemColor: AppColors.textTertiary,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Instalações',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts_outlined),
            label: 'Acessos',
          ),
          // Ícone deliberadamente diferente do de "Acessos": são coisas
          // distintas — equipa do escritório vs. clientes da app Punho.
        ],
      ),
      floatingActionButton: admin && indice != _indicePunho
          ? FloatingActionButton.small(
              tooltip: 'Pedidos Punho',
              backgroundColor: AppColors.azul,
              foregroundColor: Colors.white,
              onPressed: () => _seleccionar(_indicePunho!),
              child: const Icon(Icons.approval),
            )
          : null,
    );
  }
}
