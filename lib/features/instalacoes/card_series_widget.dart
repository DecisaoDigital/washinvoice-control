import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../core/widgets/widgets.dart';
import '../../models/licenca.dart';
import '../../models/serie_comunicada.dart';
import '../../repositories/providers.dart';
import '../../services/licenca/comunicar_serie_service.dart';

/// Card "Séries fiscais" do detalhe de um cliente.
///
/// Só aparece para clientes que **emitem** documentos fiscais (tier Pro ou
/// Legado). Clientes Base não emitem, logo não configuram acesso à AT — o card
/// não é renderizado. (O prompt fala em `tier == pro`; usa-se [Tier.temExtras]
/// para incluir também Legado, que emite e precisa de séries comunicadas.)
///
/// Fluxo: configurar acesso AT (uma vez) → comunicar séries → cada série mostra
/// o ATCUD-CV recebido da AT.
class CardSeriesFiscais extends ConsumerStatefulWidget {
  final Licenca licenca;

  /// Chamado quando o acesso AT passa a estar configurado (para o ecrã pai
  /// recarregar a licença e o chip ficar verde).
  final VoidCallback onLicencaAlterada;

  const CardSeriesFiscais({
    super.key,
    required this.licenca,
    required this.onLicencaAlterada,
  });

  @override
  ConsumerState<CardSeriesFiscais> createState() => _CardSeriesFiscaisState();
}

class _CardSeriesFiscaisState extends ConsumerState<CardSeriesFiscais> {
  late Future<List<SerieComunicada>> _future;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<List<SerieComunicada>> _carregar() =>
      ref.read(seriesRepoProvider).porLicenca(widget.licenca.id);

  void _recarregar() => setState(() {
        _future = _carregar();
      });

  Future<void> _abrirSetup() async {
    final guardou = await showDialog<bool>(
      context: context,
      builder: (_) => _ModalCredenciaisAt(machineId: widget.licenca.machineId),
    );
    if (guardou == true) widget.onLicencaAlterada();
  }

  Future<void> _abrirNovaSerie() async {
    final comunicou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ModalNovaSerie(machineId: widget.licenca.machineId),
      ),
    );
    if (comunicou == true) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    // Só clientes que emitem documentos fiscais (Pro/Legado) configuram a AT.
    if (!widget.licenca.tier.temExtras) return const SizedBox.shrink();

    final configurado = widget.licenca.acessoAtConfigurado;

    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              const Text('Séries fiscais', style: AppText.h2),
              const Spacer(),
              _ChipAcessoAt(configurado: configurado, onConfigurar: _abrirSetup),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _listaSeries(),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nova série'),
              // Só se pode comunicar depois de o acesso à AT estar configurado.
              onPressed: configurado ? _abrirNovaSerie : null,
            ),
          ),
          if (!configurado)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Configura o acesso à AT para comunicar séries.',
                style: AppText.caption,
              ),
            ),
        ],
      ),
    );
  }

  Widget _listaSeries() {
    return FutureBuilder<List<SerieComunicada>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text(descreverErro(snapshot.error!),
              style: const TextStyle(color: AppColors.vermelho));
        }
        final series = snapshot.data ?? const [];
        if (series.isEmpty) {
          return Text('Ainda sem séries comunicadas.', style: AppText.body);
        }
        return Column(
          children: [
            for (final s in series) _LinhaSerie(serie: s),
          ],
        );
      },
    );
  }
}

/// Chip de estado do acesso automático à AT.
class _ChipAcessoAt extends StatelessWidget {
  final bool configurado;
  final VoidCallback onConfigurar;
  const _ChipAcessoAt({required this.configurado, required this.onConfigurar});

  @override
  Widget build(BuildContext context) {
    if (configurado) {
      return _chip(
        cor: AppColors.verde,
        icone: Icons.check_circle,
        texto: 'Acesso AT: configurado',
      );
    }
    return InkWell(
      onTap: onConfigurar,
      borderRadius: BorderRadius.circular(20),
      child: _chip(
        cor: AppColors.laranja,
        icone: Icons.settings,
        texto: 'Configurar acesso AT',
      ),
    );
  }

  Widget _chip(
      {required Color cor, required IconData icone, required String texto}) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.tom100(cor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: AppColors.tom900(cor)),
          const SizedBox(width: 4),
          Text(texto,
              style: AppText.caption.copyWith(
                  color: AppColors.tom900(cor), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Uma linha da lista de séries: identificador + tipo + estado (ATCUD ou erro).
class _LinhaSerie extends StatelessWidget {
  final SerieComunicada serie;
  const _LinhaSerie({required this.serie});

  @override
  Widget build(BuildContext context) {
    final ok = serie.comunicada;
    final cor = ok ? AppColors.verde : AppColors.laranja;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${serie.serie} · ${serie.tipoDoc}',
                    style: AppText.bodyStrong),
                Text(Dates.data(serie.criadoEm), style: AppText.caption),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.tom100(cor),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ok ? 'Comunicada · ${serie.codigoValidacao}' : 'Por comunicar',
              style: AppText.caption.copyWith(
                  color: AppColors.tom900(cor), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal de setup das credenciais AT do cliente (uma só vez).
class _ModalCredenciaisAt extends ConsumerStatefulWidget {
  final String machineId;
  const _ModalCredenciaisAt({required this.machineId});

  @override
  ConsumerState<_ModalCredenciaisAt> createState() =>
      _ModalCredenciaisAtState();
}

class _ModalCredenciaisAtState extends ConsumerState<_ModalCredenciaisAt> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _verPassword = false;
  bool _aGuardar = false;
  String? _erro;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final u = _username.text.trim();
    final p = _password.text;
    if (u.isEmpty || p.isEmpty) {
      setState(() => _erro = 'Preenche o utilizador e a password AT.');
      return;
    }
    setState(() {
      _aGuardar = true;
      _erro = null;
    });
    try {
      await ref.read(comunicarSerieProvider).guardarCredenciais(
            widget.machineId,
            username: u,
            password: p,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acesso à AT configurado.'),
          backgroundColor: AppColors.verde700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = descreverErro(e));
    } finally {
      if (mounted) setState(() => _aGuardar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar acesso automático à AT'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para o WashInvoice comunicar séries à AT automaticamente, o '
              'cliente cria um sub-utilizador no Portal das Finanças com '
              'permissão WSE. As credenciais ficam guardadas cifradas — não '
              'voltam a ser pedidas.',
              style: AppText.body,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _username,
              autofocus: true,
              enabled: !_aGuardar,
              decoration: const InputDecoration(
                labelText: 'Utilizador AT',
                hintText: 'ex.: 515307548/1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _password,
              enabled: !_aGuardar,
              obscureText: !_verPassword,
              decoration: InputDecoration(
                labelText: 'Password AT',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                      _verPassword ? Icons.visibility_off : Icons.visibility),
                  tooltip: _verPassword
                      ? 'Ocultar palavra-passe'
                      : 'Mostrar palavra-passe',
                  onPressed: () =>
                      setState(() => _verPassword = !_verPassword),
                ),
              ),
            ),
            if (_erro != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_erro!, style: const TextStyle(color: AppColors.vermelho)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _aGuardar ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _aGuardar ? null : _guardar,
          child: _aGuardar
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Modal "Nova série" — preenche e comunica à AT.
class _ModalNovaSerie extends ConsumerStatefulWidget {
  final String machineId;
  const _ModalNovaSerie({required this.machineId});

  @override
  ConsumerState<_ModalNovaSerie> createState() => _ModalNovaSerieState();
}

class _ModalNovaSerieState extends ConsumerState<_ModalNovaSerie> {
  final _identificador = TextEditingController();
  final _numeroInicial = TextEditingController(text: '1');
  String _tipoDoc = 'FT';
  DateTime _dataInicio = DateTime.now();
  // 'OM' = Outros meios electrónicos (default, enquanto não há cert de
  // produção); 'PF' = Programa informático certificado.
  String _meio = 'OM';

  bool _aComunicar = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _identificador.text = _propostaIdentificador(_tipoDoc);
  }

  /// Proposta `<TIPO>A<ANO_VIGENTE>` (ex.: `FTA2026`). O ano nunca é hardcoded.
  String _propostaIdentificador(String tipo) => '${tipo}A${DateTime.now().year}';

  @override
  void dispose() {
    _identificador.dispose();
    _numeroInicial.dispose();
    super.dispose();
  }

  void _mudarTipo(String? novo) {
    if (novo == null) return;
    setState(() {
      _tipoDoc = novo;
      // Actualiza o prefixo proposto do identificador ao mudar de tipo.
      _identificador.text = _propostaIdentificador(novo);
    });
  }

  Future<void> _escolherData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Data de início da série',
    );
    if (d != null) setState(() => _dataInicio = d);
  }

  Future<void> _comunicar() async {
    final serie = _identificador.text.trim();
    if (serie.isEmpty) {
      setState(() => _erro = 'Indica o identificador da série.');
      return;
    }
    final num = int.tryParse(_numeroInicial.text.trim()) ?? 1;
    setState(() {
      _aComunicar = true;
      _erro = null;
    });
    try {
      final atcud = await ref.read(comunicarSerieProvider).comunicar(
            widget.machineId,
            serie: serie,
            tipoDoc: _tipoDoc,
            numeroInicial: num,
            dataInicio: _dataInicio,
            meioProcessamento: _meio,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Série $serie comunicada. ATCUD: $atcud'),
          backgroundColor: AppColors.verde700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = descreverErro(e));
    } finally {
      if (mounted) setState(() => _aComunicar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nova série', style: AppText.h2),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _identificador,
            enabled: !_aComunicar,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [UpperCaseTextFormatter()],
            decoration: const InputDecoration(
              labelText: 'Identificador',
              hintText: 'ex.: FTA2026',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _tipoDoc,
            decoration: const InputDecoration(
              labelText: 'Tipo de documento',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final t in ComunicarSerieService.tiposDoc)
                DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: _aComunicar ? null : _mudarTipo,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _numeroInicial,
            enabled: !_aComunicar,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Número inicial',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: _aComunicar ? null : _escolherData,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data de início',
                border: OutlineInputBorder(),
              ),
              child: Text(Dates.data(_dataInicio)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _meio,
            decoration: const InputDecoration(
              labelText: 'Meio de processamento',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'OM', child: Text('Outros meios electrónicos')),
              DropdownMenuItem(
                  value: 'PF', child: Text('Programa informático certificado')),
            ],
            onChanged:
                _aComunicar ? null : (v) => setState(() => _meio = v ?? 'OM'),
          ),
          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.vermelho50,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
              child: Text(_erro!,
                  style: const TextStyle(color: AppColors.vermelho900)),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _aComunicar
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_erro != null ? 'Tentar de novo' : 'Comunicar à AT'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.verde700,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _aComunicar ? null : _comunicar,
            ),
          ),
        ],
      ),
    );
  }
}

/// Força maiúsculas no identificador da série (as séries AT são em maiúsculas).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
