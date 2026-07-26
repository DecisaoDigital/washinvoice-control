import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../models/actualizacao_info.dart';
import '../../repositories/providers.dart';
import '../actualizacao/banner_actualizacao.dart';
import '../dashboard/dashboard_screen.dart';
import '../instalacoes/instalacoes_screen.dart';
import '../mapa/mapa_screen.dart';
import '../acessos/gestao_acessos_screen.dart';
import '../acessos/punho/punho_pedidos_screen.dart';

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
    });
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

    final admin = ref.watch(souAdminGlobalProvider).valueOrNull ?? false;
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
        onTap: (i) => setState(() => _index = i),
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
          if (admin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.approval),
              label: 'Punho',
            ),
        ],
      ),
    );
  }
}
