import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/erros.dart';
import '../../models/pedido_ajuda.dart';
import '../../repositories/providers.dart';
import '../../services/registo_accoes.dart';

/// Pedidos com «Resolvido» a decorrer — trava o duplo toque no mesmo cartão,
/// venha ele da lista de Pedidos de ajuda ou da fila «Agora».
final Set<String> _aResolver = {};

/// «Resolvido»: marca o pedido como resolvido e oferece «Anular» durante 8 s.
///
/// Partilhado pelos Pedidos de ajuda e pelo «Agora» — uma só regra, um só
/// SnackBar. [depois] corre no fim (sucesso ou erro) para o ecrã que chamou
/// recarregar; quem chama decide se ainda está montado.
Future<void> resolverPedidoAjuda(
  WidgetRef ref,
  PedidoAjuda p, {
  required Future<void> Function() depois,
  String? quem,
}) async {
  if (!_aResolver.add(p.id)) return;
  final repo = ref.read(pedidosAjudaRepoProvider);
  try {
    await repo.marcarResolvido(p.id);
    await registarAccao(
      ref,
      tipo: 'Pedido de ajuda',
      titulo: quem ?? ((p.nif?.isEmpty ?? true) ? 'Pedido de ajuda' : 'NIF ${p.nif}'),
      app: p.app,
      machineId: p.machineId,
      pedido: (p.notas?.trim().isEmpty ?? true) ? 'Pediu ajuda' : p.notas!.trim(),
      accao: 'Resolvido',
    );
    messengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Pedido marcado como resolvido.'),
          duration: const Duration(seconds: 8),
          persist: false, // com acção, o SnackBar não fecha sozinho se não o disserem
          action: SnackBarAction(
            label: 'Anular',
            onPressed: () => _reabrir(ref, p, depois),
          ),
        ),
      );
  } catch (e, st) {
    mostrarErro(e, stack: st);
  } finally {
    _aResolver.remove(p.id);
  }
  await depois();
}

/// «Anular» do Resolvido: volta a abrir o pedido.
Future<void> _reabrir(
  WidgetRef ref,
  PedidoAjuda p,
  Future<void> Function() depois,
) async {
  try {
    await ref.read(pedidosAjudaRepoProvider).reabrir(p.id);
    mostrarMensagem('Pedido reaberto.');
  } catch (e, st) {
    mostrarErro(e, stack: st);
  }
  await depois();
}
