import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../models/actualizacao_info.dart';
import '../../repositories/providers.dart';
import '../actualizacao/banner_actualizacao.dart';
import '../dashboard/dashboard_screen.dart';
import '../instalacoes/instalacoes_screen.dart';
import '../mapa/mapa_screen.dart';

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
  ];

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

    return Scaffold(
      body: Column(
        children: [
          const BannerActualizacao(),
          Expanded(
            child: IndexedStack(index: _index, children: _paginas),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: AppColors.azul,
        unselectedItemColor: AppColors.textTertiary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Instalações',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
        ],
      ),
    );
  }
}
