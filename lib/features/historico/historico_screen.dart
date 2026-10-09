import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_filter/app_filter_provider.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../core/widgets/widgets.dart';
import '../../repositories/historico_repository.dart';
import '../../repositories/providers.dart';
import '../nav/menu_control.dart';

/// «Histórico»: tudo o que se tratou, por dia — o que foi pedido, quando, e o
/// que se fez. O que se trata no Agora aparece aqui logo; à meia-noite sai da
/// secção «Tratados» do Agora e fica só aqui.
class HistoricoScreen extends ConsumerWidget {
  const HistoricoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(appFilterProvider);
    final historico = ref.watch(historicoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Histórico', style: TextStyle(fontSize: 18)),
            Text(
              'a ver: ${filtro == AppFiltro.todas ? 'Todas' : filtro.etiqueta}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: const [MenuControl()],
      ),
      body: Column(
        children: [
          const WiBarraApps(),
          Expanded(
            child: historico.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErroView(
                erro: e,
                onRetry: () => ref.invalidate(historicoProvider),
              ),
              data: (todos) {
                final lista = todos
                    .where((r) => r.app == null || filtro.aceita(r.app!))
                    .toList();
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(historicoProvider);
                    await ref.read(historicoProvider.future);
                  },
                  child: lista.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            WiEmptyState(
                              icone: Icons.history,
                              titulo: 'Ainda sem histórico',
                              mensagem:
                                  'O que tratares no Agora aparece aqui, por dia.',
                            ),
                          ],
                        )
                      : _ListaPorDia(registos: lista),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaPorDia extends StatelessWidget {
  const _ListaPorDia({required this.registos});

  final List<RegistoHistorico> registos;

  static String _dia(DateTime d, DateTime hoje) {
    final dia = DateTime(d.year, d.month, d.day);
    final h = DateTime(hoje.year, hoje.month, hoje.day);
    final dif = h.difference(dia).inDays;
    if (dif == 0) return 'Hoje';
    if (dif == 1) return 'Ontem · ${Dates.data(d)}';
    return Dates.data(d);
  }

  static String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final itens = <Widget>[];
    String? diaAtual;
    for (final r in registos) {
      final dia = _dia(r.criadoEm, hoje);
      if (dia != diaAtual) {
        diaAtual = dia;
        itens.add(
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
            child: Text(dia.toUpperCase(), style: AppText.label),
          ),
        );
      }
      itens.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: WiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(r.tipo, style: AppText.label)),
                    if (r.app != null) WiAppBadgeAuto(r.app!, espacoDireita: AppSpacing.sm),
                    Text(_hora(r.criadoEm), style: AppText.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(r.titulo, style: AppText.bodyStrong),
                if (r.pedido != null && r.pedido!.isNotEmpty)
                  Text('Pediu: ${r.pedido}', style: AppText.caption),
                Text('Fizemos: ${r.accao}', style: AppText.caption),
              ],
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: itens,
    );
  }
}
