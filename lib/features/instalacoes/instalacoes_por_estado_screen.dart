import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/app_colors.dart';
import '../../core/app_filter/app_filter_provider.dart';
import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/contexto_instalacoes.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../core/estado_ui.dart';
import '../../core/versoes.dart';
import '../../core/widgets/widgets.dart';
import '../../models/licenca.dart';
import '../../models/pedido_renovacao.dart';
import '../../repositories/providers.dart';
import 'detalhe_cliente_screen.dart';

/// Filtro de KPI do Dashboard: cada card abre esta lista com o estado
/// correspondente.
enum FiltroKpi { activas, pendentes, aExpirar, expiradas }

extension FiltroKpiUi on FiltroKpi {
  String get titulo {
    switch (this) {
      case FiltroKpi.activas:
        return 'Activas';
      case FiltroKpi.pendentes:
        return 'Pendentes';
      case FiltroKpi.aExpirar:
        return 'A expirar';
      case FiltroKpi.expiradas:
        return 'Expiradas';
    }
  }

  EstadoLicenca? get estado {
    switch (this) {
      case FiltroKpi.activas:
        return EstadoLicenca.activa;
      case FiltroKpi.aExpirar:
        return EstadoLicenca.aExpirar;
      case FiltroKpi.expiradas:
        return EstadoLicenca.expirada;
      case FiltroKpi.pendentes:
        return null; // usa pedidos_renovacao, não estado de licença
    }
  }
}

class _Data {
  final List<Licenca> licencas;
  final List<PedidoRenovacao> pendentes;
  final ContextoInstalacoes ctx;
  final ClassificadorVersoes classV;
  _Data(this.licencas, this.pendentes, this.ctx, this.classV);
}

class InstalacoesPorEstadoScreen extends ConsumerStatefulWidget {
  final FiltroKpi filtro;
  const InstalacoesPorEstadoScreen({super.key, required this.filtro});

  @override
  ConsumerState<InstalacoesPorEstadoScreen> createState() =>
      _InstalacoesPorEstadoScreenState();
}

class _InstalacoesPorEstadoScreenState
    extends ConsumerState<InstalacoesPorEstadoScreen> {
  late Future<_Data> _future;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<_Data> _carregar() async {
    // Este ecrã abre a partir dos KPIs do Dashboard, que já vêm filtrados —
    // sem o mesmo filtro, o total do card não batia certo com a lista.
    final app = ref.read(appFilterProvider).valorApp;

    final licencasF = ref.read(licencasRepoProvider).listar(app: app);
    final clientesF = ref.read(clientesRepoProvider).listar();
    final pingsF =
        ref.read(pingsRepoProvider).ultimosPorInstalacao(app: app);
    final pendentesF = ref.read(pedidosRepoProvider).pendentes(app: app);
    await Future.wait([licencasF, clientesF, pingsF, pendentesF]);

    final licencas = await licencasF;
    final pings = await pingsF;
    return _Data(
      licencas,
      await pendentesF,
      ContextoInstalacoes.build(
          clientes: await clientesF, licencas: licencas, pings: pings),
      ClassificadorVersoes(pings.map((p) => p.versao)),
    );
  }

  Future<void> _recarregar() async {
    setState(() { _future = _carregar(); });
    await _future;
  }

  void _abrirDetalhe(String machineId) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => DetalheClienteScreen(machineId: machineId)))
        .then((_) => _recarregar());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<_Data>(
          future: _future,
          builder: (context, snapshot) {
            final n = snapshot.hasData ? _itens(snapshot.data!).length : null;
            return Text(
                n == null ? widget.filtro.titulo : '${widget.filtro.titulo} ($n)');
          },
        ),
      ),
      body: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErroView(erro: snapshot.error!, onRetry: _recarregar);
          }
          final data = snapshot.data!;
          if (widget.filtro == FiltroKpi.pendentes) {
            return _listaPendentes(data);
          }
          return _listaLicencas(data);
        },
      ),
    );
  }

  List<Object> _itens(_Data data) => widget.filtro == FiltroKpi.pendentes
      ? data.pendentes
      : data.licencas.where((l) => l.estado == widget.filtro.estado).toList();

  Widget _vazio(String msg) => WiEmptyState(
        icone: Icons.inbox_outlined,
        titulo: 'Nada aqui',
        mensagem: msg,
      );

  Widget _listaLicencas(_Data data) {
    final licencas = data.licencas
        .where((l) => l.estado == widget.filtro.estado)
        .toList();
    if (licencas.isEmpty) {
      return _vazio('Não há instalações "${widget.filtro.titulo}".');
    }
    return RefreshIndicator(
      onRefresh: _recarregar,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: licencas.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) {
          final l = licencas[i];
          final ping = data.ctx.pingDe(l.machineId);
          return _CardLic(
            licenca: l,
            ctx: data.ctx,
            estadoVersao: data.classV.estadoDe(ping?.versao),
            versao: ping?.versao,
            onTap: () => _abrirDetalhe(l.machineId),
          );
        },
      ),
    );
  }

  Widget _listaPendentes(_Data data) {
    if (data.pendentes.isEmpty) {
      return _vazio('Não há pedidos de renovação pendentes.');
    }
    return RefreshIndicator(
      onRefresh: _recarregar,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: data.pendentes.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) {
          final p = data.pendentes[i];
          return WiCard(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            onTap: () => _abrirDetalhe(p.machineId),
            child: Row(
              children: [
                const Icon(Icons.autorenew, color: AppColors.roxo700, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          WiAppBadgeAuto(p.app),
                          Expanded(
                            child: Text(
                              data.ctx
                                  .nomeDe(machineId: p.machineId, nif: p.nif),
                              style: AppText.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Quer renovar: ${p.planoDesejado} · ${timeago.format(p.criadoEm, locale: 'pt')}',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textTertiary),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CardLic extends StatelessWidget {
  final Licenca licenca;
  final ContextoInstalacoes ctx;
  final EstadoVersao estadoVersao;
  final String? versao;
  final VoidCallback onTap;
  const _CardLic({
    required this.licenca,
    required this.ctx,
    required this.estadoVersao,
    required this.versao,
    required this.onTap,
  });

  String _validade() {
    final e = licenca.estado;
    if (e == EstadoLicenca.expirada) {
      return 'expirada ${timeago.format(licenca.validade, locale: 'pt')}';
    }
    if (e == EstadoLicenca.aExpirar) {
      return 'expira ${timeago.format(licenca.validade, locale: 'pt', allowFromNow: true)}';
    }
    return 'expira ${Dates.data(licenca.validade)}';
  }

  @override
  Widget build(BuildContext context) {
    final expirada = licenca.estado == EstadoLicenca.expirada;
    final card = WiCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 32,
            decoration: BoxDecoration(
                color: licenca.estado.cor, borderRadius: AppRadius.smAll),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    WiAppBadgeAuto(licenca.app),
                    WiTierBadge(licenca.tier),
                    Expanded(
                      child: Text(
                        ctx.nomeDe(
                            machineId: licenca.machineId, nif: licenca.nif),
                        style: AppText.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text('${licenca.planoLabel} · ${_validade()}',
                    style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          VersaoBadge(versao: versao, estado: estadoVersao),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
    return expirada ? Opacity(opacity: 0.75, child: card) : card;
  }
}
