import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';

/// Formulário para iniciar a atividade de uma instalação nova (máquina que
/// está a comunicar mas ainda não tem licença). Cria o cliente (se necessário)
/// e a licença, definindo a duração em meses.
class AtivarInstalacaoScreen extends ConsumerStatefulWidget {
  final Ping ping;
  const AtivarInstalacaoScreen({super.key, required this.ping});

  @override
  ConsumerState<AtivarInstalacaoScreen> createState() =>
      _AtivarInstalacaoScreenState();
}

class _AtivarInstalacaoScreenState
    extends ConsumerState<AtivarInstalacaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telemovelCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  final _mesesCtrl = TextEditingController(text: '1');

  String _plano = 'mensal';
  bool _aGravar = false;

  static const _mesesPorPlano = {'mensal': 1, 'trimestral': 3, 'anual': 12};

  @override
  void initState() {
    super.initState();
    _nomeCtrl.text = '';
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telemovelCtrl.dispose();
    _notasCtrl.dispose();
    _mesesCtrl.dispose();
    super.dispose();
  }

  DateTime _adicionarMeses(DateTime d, int meses) =>
      DateTime(d.year, d.month + meses, d.day, d.hour, d.minute);

  DateTime get _novaValidade {
    final meses = int.tryParse(_mesesCtrl.text.trim()) ?? 0;
    return _adicionarMeses(DateTime.now(), meses);
  }

  Future<void> _criar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _aGravar = true);
    try {
      final clientesRepo = ref.read(clientesRepoProvider);
      final licencasRepo = ref.read(licencasRepoProvider);
      final nif = widget.ping.nif ?? '';

      var cliente = nif.isNotEmpty ? await clientesRepo.porNif(nif) : null;
      cliente ??= await clientesRepo.criarNovo(
        nif: nif,
        nome: _nomeCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        telemovel:
            _telemovelCtrl.text.trim().isEmpty ? null : _telemovelCtrl.text.trim(),
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      );

      final validade = _novaValidade;
      await licencasRepo.criar(
        machineId: widget.ping.machineId,
        nif: nif,
        nome: _nomeCtrl.text.trim().isEmpty ? null : _nomeCtrl.text.trim(),
        clienteId: cliente.id,
        plano: _plano,
        validade: validade,
        activa: true,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Licença criada até ${Dates.data(validade)}'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e, st) {
      mostrarErro(e, stack: st);
    } finally {
      if (mounted) setState(() => _aGravar = false);
    }
  }

  Future<void> _enviarInstrucoes() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      mostrarErro('Preenche o email antes de enviar instruções.');
      return;
    }
    final validade = _novaValidade;
    final assunto = 'WashInvoice — Licença e instruções de pagamento';
    final corpo = 'Olá,\n\n'
        'A sua licença WashInvoice foi preparada com o plano "$_plano", '
        'válida até ${Dates.data(validade)}.\n\n'
        'Instruções de pagamento:\n'
        '- IBAN: PT50 0000 0000 0000 0000 0000 0\n'
        '- Valor: (a indicar)\n'
        '- Referência: ${widget.ping.nif ?? widget.ping.machineId}\n\n'
        'Após confirmação do pagamento a licença fica ativa.\n\n'
        'Obrigado.';
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(assunto)}'
          '&body=${Uri.encodeComponent(corpo)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) mostrarErro('Não foi possível abrir a aplicação de email.');
  }

  @override
  Widget build(BuildContext context) {
    final ping = widget.ping;
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar atividade')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Instalação',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _linha('NIF', ping.nif ?? '—'),
                    _linha('Machine ID', ping.machineId),
                    _linha('Cidade', ping.cidade ?? '—'),
                    _linha('Versão', 'v${ping.versao ?? '?'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do cliente / estabelecimento',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Indica um nome' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (para fatura / instruções de pagamento)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null; // email é opcional
                if (!t.contains('@') || !t.contains('.')) {
                  return 'Email inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telemovelCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telemóvel (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _plano,
              decoration: const InputDecoration(
                labelText: 'Plano',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'mensal', child: Text('Mensal')),
                DropdownMenuItem(
                    value: 'trimestral', child: Text('Trimestral')),
                DropdownMenuItem(value: 'anual', child: Text('Anual')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _plano = v;
                  _mesesCtrl.text = '${_mesesPorPlano[v] ?? 1}';
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mesesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duração (meses)',
                helperText: 'Quantos meses a licença fica ativa',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) return 'Indica um nº de meses válido';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Licença válida até ${Dates.data(_novaValidade)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notasCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _aGravar ? null : _criar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.verde,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _aGravar
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text('Criar licença e ativar'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _enviarInstrucoes,
              icon: const Icon(Icons.email_outlined),
              label: const Text('Enviar instruções de pagamento por email'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linha(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(rotulo,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
