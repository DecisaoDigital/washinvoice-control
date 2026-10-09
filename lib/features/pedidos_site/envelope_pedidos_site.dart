import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/app_spacing.dart';
import '../../repositories/pedidos_site_repository.dart';
import '../../repositories/providers.dart';
import '../../main.dart' show dashboardRefreshProvider;

/// Envelope do canto superior direito: pedidos do site decisaodigital.pt por
/// ver. Mostra a contagem num badge; ao tocar abre a lista de referências com
/// «Marcar como vista». Sem pedidos por ver (ou sem rede) fica discreto.
class EnvelopePedidosSite extends ConsumerStatefulWidget {
  const EnvelopePedidosSite({super.key});

  @override
  ConsumerState<EnvelopePedidosSite> createState() =>
      _EnvelopePedidosSiteState();
}

class _EnvelopePedidosSiteState extends ConsumerState<EnvelopePedidosSite> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    // Chegou um push: a contagem pode ter mudado.
    _sub = ref.read(dashboardRefreshProvider).listen((_) {
      ref.invalidate(pedidosSitePorVerProvider);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = ref.watch(pedidosSitePorVerProvider).valueOrNull?.length ?? 0;
    return IconButton(
      iconSize: 22,
      tooltip: n == 0
          ? 'Pedidos do site'
          : '$n pedido${n == 1 ? '' : 's'} do site por ver',
      icon: n == 0
          ? const Icon(Icons.mail_outline, color: Colors.white)
          : Badge(
              label: Text('$n'),
              child: const Icon(Icons.mail, color: Colors.white),
            ),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const _ListaPedidosSite(),
      ),
    );
  }
}

class _ListaPedidosSite extends ConsumerWidget {
  const _ListaPedidosSite();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(pedidosSitePorVerProvider);
    final altura = MediaQuery.of(context).size.height * 0.6;
    return SafeArea(
      child: SizedBox(
        height: altura,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pedidos do site',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: estado.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(
                      child: Text('Não foi possível carregar os pedidos.')),
                  data: (lista) => lista.isEmpty
                      ? const Center(child: Text('Nenhum pedido por ver.'))
                      : ListView.separated(
                          itemCount: lista.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => _Linha(aviso: lista[i]),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Linha extends ConsumerWidget {
  const _Linha({required this.aviso});

  final PedidoSiteAviso aviso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(aviso.ref,
          style: const TextStyle(
              fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      subtitle: Text(timeago.format(aviso.criadoEm, locale: 'pt')),
      trailing: TextButton(
        onPressed: () async {
          await ref.read(pedidosSiteRepoProvider).marcarVisto(aviso.ref);
          ref.invalidate(pedidosSitePorVerProvider);
        },
        child: const Text('Marcar como vista'),
      ),
    );
  }
}
