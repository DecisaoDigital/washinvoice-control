import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../acessos/gestao_acessos_screen.dart';
import '../acessos/punho/fist_pendentes_provider.dart';
import '../acessos/punho/punho_pedidos_screen.dart';
import '../agora/agora_modelo.dart';
import '../agora/agora_providers.dart';
import '../dashboard/dashboard_screen.dart';
import '../mapa/mapa_screen.dart';
import '../pedidos_ajuda/pedidos_ajuda_screen.dart';
import '../sobre/sobre_screen.dart';
import '../sugestoes/sugestoes_screen.dart';

/// Uma entrada da lista «Mais».
class EntradaMais {
  final String chave;
  final IconData icone;
  final String texto;

  /// Contagem a mostrar à direita (0 = nada).
  final int contagem;
  final Widget Function() ecra;

  const EntradaMais({
    required this.chave,
    required this.icone,
    required this.texto,
    required this.ecra,
    this.contagem = 0,
  });
}

/// As entradas de «Mais», pela ordem em que aparecem.
///
/// «Pedidos Fist» é exclusivo do admin global — as RPCs `punho_*_admin`
/// recusam qualquer outra conta, por isso a entrada nem existe para os outros.
/// As contagens de ajuda e sugestões vêm da fila «Agora» (a mesma fonte, sem
/// nova query).
List<EntradaMais> entradasDeMais({
  required bool admin,
  required int fistPendentes,
  required int ajudaAberta,
  required int sugestoesPorLer,
}) => [
  EntradaMais(
    chave: 'resumo',
    icone: Icons.dashboard_outlined,
    texto: 'Resumo',
    ecra: () => const DashboardScreen(),
  ),
  if (admin)
    EntradaMais(
      chave: 'pedidosFist',
      icone: Icons.how_to_reg_outlined,
      texto: 'Pedidos Fist',
      contagem: fistPendentes,
      ecra: () => const FistPedidosScreen(),
    ),
  EntradaMais(
    chave: 'acessos',
    icone: Icons.manage_accounts_outlined,
    texto: 'Acessos',
    ecra: () => const GestaoAcessosScreen(),
  ),
  EntradaMais(
    chave: 'mapa',
    icone: Icons.map_outlined,
    texto: 'Mapa',
    ecra: () => const MapaScreen(),
  ),
  EntradaMais(
    chave: 'sugestoes',
    icone: Icons.lightbulb_outline,
    texto: 'Sugestões',
    contagem: sugestoesPorLer,
    ecra: () => const SugestoesScreen(),
  ),
  EntradaMais(
    chave: 'pedidosAjuda',
    icone: Icons.help_outline,
    texto: 'Pedidos de ajuda (histórico)',
    contagem: ajudaAberta,
    ecra: () => const PedidosAjudaScreen(),
  ),
  EntradaMais(
    chave: 'sobre',
    icone: Icons.info_outline,
    texto: 'Sobre',
    ecra: () => const SobreScreen(),
  ),
];

/// Terceiro separador: tudo o que já não vive na barra de baixo, numa lista
/// simples. Cada entrada abre o ecrã que já existia, por cima (push de rota).
class MaisScreen extends ConsumerWidget {
  const MaisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(souAdminGlobalProvider).valueOrNull ?? false;
    final contagem =
        ref.watch(agoraProvider).valueOrNull?.contagem ??
        const <TipoAgora, int>{};
    final entradas = entradasDeMais(
      admin: admin,
      fistPendentes: ref.watch(fistPendentesTotalProvider),
      ajudaAberta: contagem[TipoAgora.ajuda] ?? 0,
      sugestoesPorLer: contagem[TipoAgora.sugestao] ?? 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: entradas.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) {
          final e = entradas[i];
          return Material(
            color: AppColors.surface,
            elevation: 1,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: ValueKey('mais_${e.chave}'),
              minTileHeight: 56,
              leading: Icon(e.icone, color: AppColors.azul900),
              title: Text(e.texto),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (e.contagem > 0)
                    Badge(
                      label: Text('${e.contagem}'),
                      backgroundColor: AppColors.vermelho,
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => e.ecra())),
            ),
          );
        },
      ),
    );
  }
}
