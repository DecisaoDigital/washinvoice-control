import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/acoes.dart';
import '../../core/app_colors.dart';
import '../../core/app_filter/app_filter_provider.dart';
import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/contexto_instalacoes.dart';
import '../../core/erros.dart';
import '../../core/widgets/widgets.dart';
import '../../models/pedido_ajuda.dart';
import '../../repositories/providers.dart';
import 'detalhe_pedido_ajuda_screen.dart';
import 'resolver_pedido_ajuda.dart';

/// Formata uma duração de forma curta em PT (ex.: "2 h", "3 d", "45 min").
String formatarDuracao(Duration? d) {
  if (d == null) return '—';
  if (d.inDays >= 1) return '${d.inDays} d';
  if (d.inHours >= 1) return '${d.inHours} h';
  if (d.inMinutes >= 1) return '${d.inMinutes} min';
  return '${d.inSeconds} s';
}

class _PedidosData {
  final List<PedidoAjuda> abertos;
  final List<PedidoAjuda> historico;
  final ContextoInstalacoes ctx;

  _PedidosData({
    required this.abertos,
    required this.historico,
    required this.ctx,
  });
}

class PedidosAjudaScreen extends ConsumerStatefulWidget {
  const PedidosAjudaScreen({super.key});

  @override
  ConsumerState<PedidosAjudaScreen> createState() => _PedidosAjudaScreenState();
}

class _PedidosAjudaScreenState extends ConsumerState<PedidosAjudaScreen> {
  late Future<_PedidosData> _future;
  bool _mostrarHistorico = false;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<_PedidosData> _carregar() async {
    final ajudaRepo = ref.read(pedidosAjudaRepoProvider);
    final clientesRepo = ref.read(clientesRepoProvider);
    final licencasRepo = ref.read(licencasRepoProvider);
    final pingsRepo = ref.read(pingsRepoProvider);

    final app = ref.read(appFilterProvider).valorApp;

    final abertos = ajudaRepo.listarAbertos(app: app);
    final historico = ajudaRepo.listarHistorico(app: app);
    final clientes = clientesRepo.listar();
    final licencas = licencasRepo.listar(app: app);
    final pings = pingsRepo.ultimosPorInstalacao(app: app);
    await Future.wait([abertos, historico, clientes, licencas, pings]);

    return _PedidosData(
      abertos: await abertos,
      historico: await historico,
      ctx: ContextoInstalacoes.build(
        clientes: await clientes,
        licencas: await licencas,
        pings: await pings,
      ),
    );
  }

  Future<void> _recarregar() async {
    setState(() {
      _future = _carregar();
    });
    await _future;
  }

  /// «Resolvido» (+ «Anular») vive em `resolver_pedido_ajuda.dart`, partilhado
  /// com a fila «Agora». Recarrega no fim, se o ecrã ainda existir.
  Future<void> _resolver(PedidoAjuda p) => resolverPedidoAjuda(
    ref,
    p,
    depois: () async {
      if (mounted) await _recarregar();
    },
  );

  void _abrirDetalhe(PedidoAjuda p) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DetalhePedidoAjudaScreen(pedido: p),
          ),
        )
        .then((_) => _recarregar());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appFilterProvider, (_, __) => _recarregar());

    return Scaffold(
      appBar: AppBar(
        title: const _TituloAppBar(),
        actions: const [
          WiAppSelector(),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: WiComPastilhaApp(
        corpo: FutureBuilder<_PedidosData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErroView(erro: snapshot.error!, onRetry: _recarregar);
            }
            final data = snapshot.data!;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _Toggle(
                    abertos: data.abertos.length,
                    historico: data.historico.length,
                    mostrarHistorico: _mostrarHistorico,
                    onChanged: (v) => setState(() => _mostrarHistorico = v),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _recarregar,
                    child: _mostrarHistorico
                        ? _ListaHistorico(data, onAbrir: _abrirDetalhe)
                        : _ListaAbertos(
                            data,
                            onResolver: _resolver,
                            onAbrir: _abrirDetalhe,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TituloAppBar extends StatelessWidget {
  const _TituloAppBar();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [Text('Pedidos de ajuda', style: TextStyle(fontSize: 18))],
    );
  }
}

class _Toggle extends StatelessWidget {
  final int abertos;
  final int historico;
  final bool mostrarHistorico;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.abertos,
    required this.historico,
    required this.mostrarHistorico,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.fundo,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: AppColors.borda),
      ),
      child: Row(
        children: [
          _seg('Abertos ($abertos)', !mostrarHistorico, () => onChanged(false)),
          _seg(
            'Histórico ($historico)',
            mostrarHistorico,
            () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _seg(String label, bool activo, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: activo ? AppColors.azul900 : Colors.transparent,
        borderRadius: AppRadius.pillAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: activo ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListaAbertos extends StatelessWidget {
  final _PedidosData data;
  final Future<void> Function(PedidoAjuda) onResolver;
  final void Function(PedidoAjuda) onAbrir;
  const _ListaAbertos(
    this.data, {
    required this.onResolver,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    if (data.abertos.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          WiEmptyState(
            icone: Icons.check_circle_outline,
            titulo: 'Sem pedidos abertos',
            mensagem: 'Nenhum cliente está à espera de ajuda neste momento.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: data.abertos.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final p = data.abertos[i];
        final cliente = data.ctx.clienteDe(
          clienteId: p.clienteId,
          machineId: p.machineId,
          nif: p.nif,
        );
        return _CardAberto(
          pedido: p,
          nome: data.ctx.nomeDe(machineId: p.machineId, nif: p.nif),
          sinalLocalidade: data.ctx.sinalLocalidadeDe(
            machineId: p.machineId,
            nif: p.nif,
          ),
          telefone: cliente?.telemovel,
          onResolver: () => onResolver(p),
          onAbrir: () => onAbrir(p),
        );
      },
    );
  }
}

class _CardAberto extends StatelessWidget {
  final PedidoAjuda pedido;
  final String nome;
  final String sinalLocalidade;
  final String? telefone;
  final VoidCallback onResolver;
  final VoidCallback onAbrir;

  const _CardAberto({
    required this.pedido,
    required this.nome,
    required this.sinalLocalidade,
    required this.telefone,
    required this.onResolver,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final tempo = timeago.format(pedido.criadoEm, locale: 'pt');
    return WiCardDestaque(
      cor: AppColors.laranja500,
      onTap: onAbrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.help, color: AppColors.laranja700, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        WiAppBadgeAuto(pedido.app),
                        Expanded(
                          child: Text(
                            nome,
                            style: AppText.bodyStrong,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(sinalLocalidade, style: AppText.caption),
                    Text(
                      '$tempo${telefone != null ? ' · $telefone' : ''}',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: telefone == null
                      ? null
                      : () => Acoes.ligarPara(telefone),
                  icon: const Icon(Icons.phone, size: 18),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.azul700,
                  ),
                  label: const Text('Ligar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onResolver,
                  icon: const Icon(Icons.check, size: 18),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.verde700,
                  ),
                  label: const Text('Resolvido'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListaHistorico extends StatelessWidget {
  final _PedidosData data;
  final void Function(PedidoAjuda) onAbrir;
  const _ListaHistorico(this.data, {required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    if (data.historico.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          WiEmptyState(
            icone: Icons.history,
            titulo: 'Histórico vazio',
            mensagem: 'Ainda não há pedidos resolvidos.',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Histórico · ${data.historico.length} resolvidos',
            style: AppText.label,
          ),
        ),
        ...data.historico.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _CardHistorico(
              pedido: p,
              nome: data.ctx.nomeDe(machineId: p.machineId, nif: p.nif),
              onAbrir: () => onAbrir(p),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardHistorico extends StatelessWidget {
  final PedidoAjuda pedido;
  final String nome;
  final VoidCallback onAbrir;
  const _CardHistorico({
    required this.pedido,
    required this.nome,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final resolvido = pedido.resolvidoEm == null
        ? '—'
        : timeago.format(pedido.resolvidoEm!, locale: 'pt');
    return WiCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      onTap: onAbrir,
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.verde700, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    WiAppBadgeAuto(pedido.app),
                    Expanded(
                      child: Text(
                        nome,
                        style: AppText.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Resolvido $resolvido · duração ${formatarDuracao(pedido.duracao)}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
