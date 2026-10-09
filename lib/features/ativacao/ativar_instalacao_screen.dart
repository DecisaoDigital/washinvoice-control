import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../core/localidades.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';
import 'email_acolhimento.dart';

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
  final _mesesCtrl = TextEditingController();

  /// Plano interno gravado no Supabase.
  String _plano = 'personalizado';

  /// Botão de atalho seleccionado (3, 6 ou 12 meses). `null` = duração
  /// personalizada (editada à mão, sem botão activo).
  int? _mesesSelecionado;

  /// Licença gratuita (oferta) quando `true`; paga quando `false`.
  bool _oferta = false;

  bool _aGravar = false;

  /// Planos oferecidos e a duração correspondente em meses. Fonte única de
  /// verdade — os botões de atalho (3/6/12) derivam daqui o plano nomeado.
  static const _mesesPorPlano = {
    'trimestral': 3,
    'semestral': 6,
    'anual': 12,
  };

  /// Plano nomeado correspondente a uma duração de atalho (3/6/12 meses).
  String _planoParaMeses(int meses) =>
      _mesesPorPlano.entries.firstWhere((e) => e.value == meses).key;

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

  DateTime get _novaValidade {
    final meses = int.tryParse(_mesesCtrl.text.trim()) ?? 0;
    return Dates.adicionarMeses(DateTime.now(), meses);
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
        oferta: _oferta,
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

  Future<void> _enviarAcolhimento() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      mostrarErro('Preenche o email antes de enviar.');
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(assuntoAcolhimento)}'
          '&body=${Uri.encodeComponent(corpoAcolhimento())}',
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
                    _linha(
                        'Cidade',
                        Localidades.traduzir(ping.cidade).isEmpty
                            ? '—'
                            : Localidades.traduzir(ping.cidade)),
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
                labelText: 'Email (para contacto)',
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
            const Text('Plano',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            // Atalhos: carregar preenche a duração e fixa o plano nomeado.
            // Editar a duração à mão limpa a selecção (plano personalizado).
            SegmentedButton<int>(
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 3, label: Text('3 meses')),
                ButtonSegment(value: 6, label: Text('6 meses')),
                ButtonSegment(value: 12, label: Text('12 meses')),
              ],
              selected:
                  _mesesSelecionado == null ? <int>{} : {_mesesSelecionado!},
              onSelectionChanged: (sel) {
                setState(() {
                  if (sel.isEmpty) {
                    _mesesSelecionado = null;
                    _plano = 'personalizado';
                  } else {
                    final meses = sel.first;
                    _mesesSelecionado = meses;
                    _plano = _planoParaMeses(meses);
                    _mesesCtrl.text = '$meses';
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _oferta,
              onChanged: (v) => setState(() => _oferta = v),
              title: const Text('Oferta (licença gratuita)'),
              subtitle: const Text('Sem pagamento — a licença é gratuita'),
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
              onChanged: (_) => setState(() {
                // Edição manual → sem botão activo, plano personalizado.
                _mesesSelecionado = null;
                _plano = 'personalizado';
              }),
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
              onPressed: _enviarAcolhimento,
              icon: const Icon(Icons.email_outlined),
              label: const Text('Enviar email de acolhimento'),
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
