import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../repositories/punho_admin_repository.dart';

/// Novo limite escolhido no diálogo — devolvido por `Navigator.pop`, tal como
/// [DecisaoFist]. Quem chama a RPC é o ecrã, não o diálogo: assim isto é
/// montável num teste sem Supabase.
class NovoLimite {
  final int valor;
  const NovoLimite(this.valor);
}

/// Diálogo de edição do limite de colaboradores activos de uma empresa já
/// existente — fora do fluxo de aprovação de um pedido, que só define o
/// limite na criação.
class FistEditarLimiteModal extends StatefulWidget {
  const FistEditarLimiteModal({super.key, required this.empresa});

  final FistEmpresa empresa;

  @override
  State<FistEditarLimiteModal> createState() =>
      _FistEditarLimiteModalState();
}

class _FistEditarLimiteModalState extends State<FistEditarLimiteModal> {
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

  /// Sobe ou desce um pack (3). Parte de 0 se o campo estiver vazio ou inválido.
  void _passo(int delta) {
    final atual = _valorValido ?? 0;
    final novo = (atual + delta).clamp(1, 9999);
    setState(() => _limite.text = '$novo');
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
              helperText: 'Os operadores vendem-se em packs de 3.',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              OutlinedButton(
                onPressed: (novo ?? 0) > 3 ? () => _passo(-3) : null,
                child: const Text('− 1 pack'),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => _passo(3),
                child: const Text('+ 1 pack'),
              ),
            ],
          ),
          if (novo != null && novo % 3 != 0)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Não é múltiplo de 3. Podes gravar na mesma, mas os packs '
                'vendem-se de 3 em 3.',
                style: TextStyle(color: AppColors.laranja700, fontSize: 12),
              ),
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
