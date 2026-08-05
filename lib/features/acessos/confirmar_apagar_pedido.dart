import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';

/// Pergunta antes de apagar um pedido, e pergunta a sério.
///
/// Apagar é a única acção destas listas que não se desfaz: decidir muda um
/// estado e pode voltar atrás, apagar tira a linha do servidor e mais ninguém
/// a vê. Por isso a caixa diz **de quem** é o pedido antes de perguntar — numa
/// lista de vinte linhas iguais, "Apagar?" sem nome é um convite a enganos.
///
/// E quando o pedido está aprovado avisa do que ninguém adivinha sozinho: é
/// aquela linha que dá acesso à pessoa. Apagá-la é pô-la fora, não arrumar a
/// lista.
Future<bool> confirmarApagarPedido(
  BuildContext context, {
  required String quem,
  required String email,
  required String estado,
}) async {
  final aprovado = estado == 'aprovado';
  final resposta = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: const Text('Apagar este pedido?'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(quem, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(email, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Some do servidor e não há como o trazer de volta.',
          ),
          if (aprovado) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Este pedido está aprovado — é ele que dá acesso a esta '
              'pessoa. Apagá-lo tira-lhe a entrada na app.',
              style: const TextStyle(
                color: AppColors.vermelho,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.vermelho),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Apagar'),
        ),
      ],
    ),
  );
  return resposta ?? false;
}
