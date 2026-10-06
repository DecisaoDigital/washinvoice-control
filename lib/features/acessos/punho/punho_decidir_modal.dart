import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../repositories/punho_admin_repository.dart';

/// O que o admin escolheu no diálogo de decisão.
class DecisaoFist {
  final String decisao;
  final String? empresaId;
  final int limiteUtilizadores;
  const DecisaoFist(this.decisao, {this.empresaId, this.limiteUtilizadores = 1});
}

/// Diálogo de decisão de um pedido pendente.
///
/// Público e sem dependências de rede: recebe o pedido e as empresas já
/// carregadas e devolve a escolha por `Navigator.pop`. Quem chama a RPC é o
/// ecrã — assim isto é montável num teste sem Supabase.
class FistDecidirModal extends StatefulWidget {
  const FistDecidirModal({
    super.key,
    required this.pedido,
    required this.empresas,
  });

  final FistPedido pedido;
  final List<FistEmpresa> empresas;

  @override
  State<FistDecidirModal> createState() => _FistDecidirModalState();
}

class _FistDecidirModalState extends State<FistDecidirModal> {
  /// `true` = criar empresa nova com o nome indicado no registo.
  bool _criarNova = true;
  String? _empresaId;
  final _limite = TextEditingController(text: '1');

  @override
  void dispose() {
    _limite.dispose();
    super.dispose();
  }

  int get _limiteValido {
    final n = int.tryParse(_limite.text.trim()) ?? 1;
    return n < 1 ? 1 : n;
  }

  bool get _podeAprovar => widget.pedido.porConvite || _criarNova || _empresaId != null;

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    return AlertDialog(
      title: const Text('Decidir pedido'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.nomeApresentavel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(p.email),
            const SizedBox(height: AppSpacing.md),
            if (p.porConvite) ..._porConvite(p) else ..._livre(p),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(context, const DecisaoFist('recusar')),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.vermelho),
          child: const Text('Recusar'),
        ),
        FilledButton(
          onPressed: _podeAprovar
              ? () => Navigator.pop(
                  context,
                  DecisaoFist(
                    'aprovar',
                    empresaId: p.porConvite || _criarNova ? null : _empresaId,
                    limiteUtilizadores: _limiteValido,
                  ),
                )
              : null,
          child: const Text('Aprovar'),
        ),
      ],
    );
  }

  /// Por convite a empresa é a do convite e não se escolhe nada.
  List<Widget> _porConvite(FistPedido p) => [
    const Text('Entrada por convite.'),
    const SizedBox(height: AppSpacing.sm),
    Text(
      'Vai criar ou reactivar o acesso à empresa '
      '${p.conviteEmpresaNome ?? 'do convite'}, como ${p.perfilApresentavel.toLowerCase()}.',
    ),
    const SizedBox(height: AppSpacing.sm),
    const Text(
      'A empresa vem do convite e não pode ser mudada aqui.',
      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
  ];

  /// Pedido livre: criar empresa nova ou anexar a uma existente.
  List<Widget> _livre(FistPedido p) => [
    const Text('Pedido livre. Escolha a empresa de destino.'),
    const SizedBox(height: AppSpacing.sm),
    // `RadioGroup` e não `groupValue`/`onChanged` em cada tile: a partir do
    // Flutter 3.32 é o grupo que guarda a escolha e recebe a mudança. Com a
    // API antiga, os dois tiles repetiam o estado e nada obrigava a que
    // falassem do mesmo — dois `groupValue` diferentes compilavam na mesma.
    //
    // O campo do limite fica **dentro** do grupo, entre os dois tiles, porque é
    // onde pertence visualmente: pertence à opção de cima.
    RadioGroup<bool>(
      groupValue: _criarNova,
      onChanged: (v) => setState(() => _criarNova = v ?? true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioListTile<bool>(
            value: true,
            contentPadding: EdgeInsets.zero,
            // O nome que o pedido indica fica no rótulo: quem aprova precisa de
            // ver o que vai ser criado, não só que vai criar alguma coisa.
            title: Text('Criar nova "${p.organizacaoIndicada}"'),
          ),
          if (_criarNova)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xxl,
                bottom: AppSpacing.sm,
              ),
              child: TextField(
                controller: _limite,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Limite de utilizadores',
                ),
              ),
            ),
          RadioListTile<bool>(
            value: false,
            contentPadding: EdgeInsets.zero,
            title: const Text('Anexar a empresa existente'),
            // Sem empresas onde anexar, a opção não se pode escolher. Antes
            // isto era `onChanged: null`; agora é o `enabled`, porque quem
            // decide o que acontece ao tocar passou a ser o grupo.
            enabled: widget.empresas.isNotEmpty,
          ),
        ],
      ),
    ),
    if (!_criarNova)
      Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xxl),
        child: DropdownButtonFormField<String>(
          initialValue: _empresaId,
          decoration: const InputDecoration(labelText: 'Empresa'),
          items: widget.empresas
              .map(
                (e) => DropdownMenuItem(
                  value: e.id,
                  child: Text('${e.nome} · ${e.ocupacao}'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _empresaId = v),
        ),
      ),
    if (!_criarNova && _empresaNoLimite)
      const Padding(
        padding: EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          'Esta empresa já está no limite de utilizadores. Trate da vaga extra antes de aprovar.',
          style: TextStyle(color: AppColors.vermelho, fontSize: 12),
        ),
      ),
    const SizedBox(height: AppSpacing.sm),
    const Text(
      'A conta aprovada fica gestora da empresa.',
      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
  ];

  bool get _empresaNoLimite {
    if (_empresaId == null) return false;
    for (final e in widget.empresas) {
      if (e.id == _empresaId) return e.noLimite;
    }
    return false;
  }
}

/// Confirmação de revogação, com o impacto à vista.
class FistRevogarModal extends StatelessWidget {
  const FistRevogarModal({super.key, required this.pedido});
  final FistPedido pedido;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Revogar acesso'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${pedido.nomeApresentavel} (${pedido.email}) perde o acesso ao Fist '
          'no próximo arranque da app.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'A conta deixa de ser membro activo'
          '${pedido.empresaDestinoNome == null ? '' : ' de ${pedido.empresaDestinoNome}'}'
          ' e liberta uma vaga. Nada é apagado — pode voltar a aprovar depois.',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.vermelho),
        onPressed: () => Navigator.pop(context, const DecisaoFist('revogar')),
        child: const Text('Revogar'),
      ),
    ],
  );
}
