import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/erros.dart';
import '../../repositories/providers.dart';

class ConvitesScreen extends ConsumerStatefulWidget {
  const ConvitesScreen({super.key});
  @override
  ConsumerState<ConvitesScreen> createState() => _ConvitesScreenState();
}

class _ConvitesScreenState extends ConsumerState<ConvitesScreen> {
  final _email = TextEditingController();
  String _cargo = 'funcionario';
  bool _aEnviar = false;
  @override void dispose() { _email.dispose(); super.dispose(); }
  Future<void> _criar() async {
    if (_email.text.trim().isEmpty) return;
    setState(() => _aEnviar = true);
    try {
      final convite = await ref.read(acessosRepoProvider).criarConvite(_email.text.trim(), _cargo);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => AlertDialog(
        title: const Text('Convite criado'),
        content: SelectableText('Partilhe este código com ${_email.text.trim()}:\n\n${convite['codigo']}\n\nO convite expira em 14 dias e continua sujeito à aprovação da WashInvoice.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
      ));
      _email.clear();
    } catch (e) { if (mounted) mostrarErro(e); }
    finally { if (mounted) setState(() => _aEnviar = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Convidar funcionário')),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('O convite associa o pedido à sua organização. A entrada só fica ativa depois da aprovação da WashInvoice.'),
      const SizedBox(height: 20),
      TextField(controller: _email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email do funcionário')),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(initialValue: _cargo, decoration: const InputDecoration(labelText: 'Cargo'),
        items: const [DropdownMenuItem(value: 'funcionario', child: Text('Funcionário')),
          DropdownMenuItem(value: 'admin', child: Text('Administrador'))],
        onChanged: (v) => setState(() => _cargo = v ?? 'funcionario')),
      const SizedBox(height: 22),
      FilledButton(onPressed: _aEnviar ? null : _criar,
        child: Text(_aEnviar ? 'A criar…' : 'Criar convite')),
    ])),
  );
}
