import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/erros.dart';
import '../../../repositories/providers.dart';
import '../../../repositories/punho_admin_repository.dart';
import '../../../services/registo_accoes.dart';
import 'fist_pendentes_provider.dart';
import 'punho_decidir_modal.dart';

/// Aplica a decisão [escolha] ao pedido Fist — a RPC `punho_decidir_pedido` e a
/// mensagem de resultado. Partilhado pelo ecrã «Pedidos Fist» e pela fila
/// «Agora»; assim a regra (e o SnackBar) é uma só.
///
/// [aOcupar] avisa quem chama de que a RPC começou (`true`) e acabou (`false`),
/// para mostrar progresso. Devolve `true` se a decisão foi gravada.
Future<bool> aplicarDecisaoFist(
  WidgetRef ref,
  FistPedido pedido,
  DecisaoFist escolha, {
  void Function(bool ocupado)? aOcupar,
}) async {
  aOcupar?.call(true);
  try {
    final resultado = await ref
        .read(punhoAdminRepoProvider)
        .decidir(
          pedido.id,
          escolha.decisao,
          empresaId: escolha.empresaId,
          limiteUtilizadores: escolha.limiteUtilizadores,
        );
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'Pedido de ${pedido.nomeApresentavel}: ${resultado['estado_novo']}.',
        ),
      ),
    );
    // O badge e a fila «Agora» contam estes pedidos: já não está pendente.
    ref.invalidate(fistPendentesProvider);
    await registarAccao(
      ref,
      tipo: 'Pedido de acesso',
      titulo: pedido.nomeApresentavel,
      app: 'punho',
      pedido: pedido.organizacaoIndicada.isEmpty
          ? 'Pediu acesso'
          : 'Pediu acesso (${pedido.organizacaoIndicada})',
      accao: escolha.decisao == 'recusar' ? 'Recusado' : 'Aceite',
    );
    return true;
  } catch (e) {
    mostrarErro(e);
    return false;
  } finally {
    aOcupar?.call(false);
  }
}

/// Abre o modal «Decidir» e, se o Cesar escolher, aplica a decisão.
Future<bool> abrirDecisaoFist(
  BuildContext context,
  WidgetRef ref,
  FistPedido pedido,
  List<FistEmpresa> empresas, {
  void Function(bool ocupado)? aOcupar,
}) async {
  final escolha = await showDialog<DecisaoFist>(
    context: context,
    builder: (_) => FistDecidirModal(pedido: pedido, empresas: empresas),
  );
  if (escolha == null) return false;
  return aplicarDecisaoFist(ref, pedido, escolha, aOcupar: aOcupar);
}
