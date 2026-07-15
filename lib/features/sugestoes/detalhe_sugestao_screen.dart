import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/contexto_instalacoes.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../core/widgets/widgets.dart';
import '../../models/cliente.dart';
import '../../models/licenca.dart';
import '../../models/sugestao.dart';
import '../../repositories/providers.dart';
import '../instalacoes/detalhe_cliente_screen.dart';

class _DetalheData {
  final ContextoInstalacoes ctx;
  final Cliente? cliente;
  final Licenca? licenca;
  _DetalheData(this.ctx, this.cliente, this.licenca);
}

class DetalheSugestaoScreen extends ConsumerStatefulWidget {
  final Sugestao sugestao;
  const DetalheSugestaoScreen({super.key, required this.sugestao});

  @override
  ConsumerState<DetalheSugestaoScreen> createState() =>
      _DetalheSugestaoScreenState();
}

class _DetalheSugestaoScreenState
    extends ConsumerState<DetalheSugestaoScreen> {
  late Future<_DetalheData> _future;
  late Sugestao _sugestao;

  @override
  void initState() {
    super.initState();
    _sugestao = widget.sugestao;
    _future = _carregar();
  }

  Future<_DetalheData> _carregar() async {
    final clientesRepo = ref.read(clientesRepoProvider);
    final licencasRepo = ref.read(licencasRepoProvider);
    final pingsRepo = ref.read(pingsRepoProvider);

    final clientesF = clientesRepo.listar();
    final licencasF = licencasRepo.listar();
    final pingsF = pingsRepo.ultimosPorInstalacao();
    await Future.wait([clientesF, licencasF, pingsF]);

    final ctx = ContextoInstalacoes.build(
      clientes: await clientesF,
      licencas: await licencasF,
      pings: await pingsF,
    );
    final cliente = ctx.clienteDe(
      clienteId: _sugestao.clienteId,
      machineId: _sugestao.machineId,
      nif: _sugestao.nif,
    );
    final licenca =
        _sugestao.machineId == null ? null : ctx.licencaDe(_sugestao.machineId!);
    return _DetalheData(ctx, cliente, licenca);
  }

  Future<void> _recarregar() async {
    setState(() => _future = _carregar());
    await _future;
  }

  Future<void> _toggleMarcar() async {
    final novo = !_sugestao.marcada;
    await ref.read(sugestoesRepoProvider).marcarMarcada(_sugestao.id, novo);
    setState(() => _sugestao = _sugestao.copyWith(marcada: novo));
  }

  Future<void> _arquivar() async {
    await ref.read(sugestoesRepoProvider).arquivar(_sugestao.id);
    setState(() =>
        _sugestao = _sugestao.copyWith(arquivada: true, lida: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sugestão arquivada.')),
    );
  }

  Future<void> _copiar(String machineId) async {
    await Clipboard.setData(ClipboardData(text: machineId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Machine ID copiado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<_DetalheData>(
          future: _future,
          builder: (context, snapshot) {
            final nome = snapshot.data?.ctx.nomeDe(
                    machineId: _sugestao.machineId ?? '', nif: _sugestao.nif) ??
                (_sugestao.nif != null ? 'NIF ${_sugestao.nif}' : 'Sugestão');
            return Text(nome,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500));
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: _chips()),
          ),
        ],
      ),
      body: FutureBuilder<_DetalheData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErroView(erro: snapshot.error!, onRetry: _recarregar);
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _cardSugestao(),
              const SizedBox(height: AppSpacing.md),
              _cardCliente(data),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(_sugestao.marcada ? Icons.star : Icons.star_border),
                  label: Text(_sugestao.marcada
                      ? 'Desmarcar'
                      : 'Marcar como importante'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.laranja700,
                    side: const BorderSide(color: AppColors.laranja700),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _toggleMarcar,
                ),
              ),
              if (!_sugestao.arquivada) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Arquivar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.verde700,
                      side: const BorderSide(color: AppColors.verde700),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _arquivar,
                  ),
                ),
              ],
              if (_sugestao.machineId != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DetalheClienteScreen(
                          machineId: _sugestao.machineId!),
                    )),
                    child: const Text('Ver ficha completa do cliente'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _chips() {
    final chips = <Widget>[];
    if (!_sugestao.lida) {
      chips.add(_Pill('Por ler', AppColors.roxo100, AppColors.roxo900));
    }
    if (_sugestao.marcada) {
      chips.add(_Pill('Marcada', AppColors.laranja100, AppColors.laranja900,
          icone: Icons.star));
    }
    if (_sugestao.arquivada) {
      chips.add(_Pill('Arquivada', AppColors.fundo, AppColors.textSecondary));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          chips[i],
        ],
      ],
    );
  }

  Widget _cardSugestao() {
    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WiCardTitulo(
              icone: Icons.lightbulb_outline,
              titulo: 'Sugestão',
              corIcone: AppColors.roxo700),
          SelectableText(_sugestao.texto,
              style: AppText.body.copyWith(height: 1.5)),
          const SizedBox(height: AppSpacing.sm),
          WiLinhaKV(
            rotulo: 'Enviada em',
            valor:
                '${timeago.format(_sugestao.criadoEm, locale: 'pt')} · ${Dates.dataHora(_sugestao.criadoEm)}',
          ),
        ],
      ),
    );
  }

  Widget _cardCliente(_DetalheData data) {
    final machineId = _sugestao.machineId;
    final machineCurto = machineId == null
        ? '—'
        : (machineId.length > 12 ? '${machineId.substring(0, 12)}…' : machineId);
    final loja = (data.cliente?.localidade != null &&
            data.cliente!.localidade!.trim().isNotEmpty)
        ? data.cliente!.localidade!.trim()
        : '—';
    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WiCardTitulo(
              icone: Icons.store_outlined, titulo: 'Cliente / Terminal'),
          WiLinhaKV(
            rotulo: 'Nome',
            valor: data.ctx
                .nomeDe(machineId: machineId ?? '', nif: _sugestao.nif),
          ),
          WiLinhaKV(rotulo: 'NIF', valor: _sugestao.nif ?? '—'),
          WiLinhaKV(rotulo: 'Localidade', valor: loja),
          WiLinhaKV(
            rotulo: 'Máquina',
            valor: machineCurto,
            mono: true,
            trailing: machineId == null
                ? null
                : InkWell(
                    onTap: () => _copiar(machineId),
                    child: const Icon(Icons.copy,
                        size: 18, color: AppColors.textTertiary),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                const SizedBox(
                    width: 100, child: Text('Licença', style: AppText.label)),
                if (data.licenca != null)
                  WiBadgeEstado(data.licenca!.estado)
                else
                  _Pill('Sem licença', AppColors.fundo, AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color fundo;
  final Color forte;
  final IconData? icone;
  const _Pill(this.label, this.fundo, this.forte, {this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: fundo, borderRadius: AppRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 12, color: forte),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  color: forte, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
