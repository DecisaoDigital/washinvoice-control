import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../repositories/punho_admin_repository.dart';

/// Novo limite escolhido no diálogo — devolvido por `Navigator.pop`, tal como
/// [DecisaoPunho]. Quem chama a RPC é o ecrã, não o diálogo: assim isto é
/// montável num teste sem Supabase.
class NovoLimite {
  final int valor;
  const NovoLimite(this.valor);
}

/// Diálogo de edição do limite de colaboradores activos de uma empresa já
/// existente — fora do fluxo de aprovação de um pedido, que só define o
/// limite na criação.
class PunhoEditarLimiteModal extends StatefulWidget {
  const PunhoEditarLimiteModal({super.key, required this.empresa});

  final PunhoEmpresa empresa;

  @override
  State<PunhoEditarLimiteModal> createState() =>
      _PunhoEditarLimiteModalState();
}

class _PunhoEditarLimiteModalState extends State<PunhoEditarLimiteModal> {
  late final _limite = TextEditingController(
    text: '${widget.empresa.limiteUtilizadores}',
  );

  @override
  void dispose() {
    _limite.dispose();
    super.dispose();
  }

  int? get _valorValido {
    final n = int.tryParse(_limite.text.trim());
    return (n == null || n < 1) ? null : n;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.empresa;
    final novo = _valorValido;
    final abaixoDosAtivos = novo != null && novo < e.ativos;

    return AlertDialog(
      title: Text('Editar limite — ${e.nome}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ocupação actual: ${e.ocupacao}'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _limite,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Limite de colaboradores',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (abaixoDosAtivos)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Fica abaixo dos colaboradores já activos. Ninguém é desligado '
                '— só bloqueia o acesso de novos colaboradores acima do limite.',
                style: TextStyle(color: AppColors.laranja700, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: novo == null
              ? null
              : () => Navigator.pop(context, NovoLimite(_valorValido!)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
