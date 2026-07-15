import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/acoes.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/config.dart';
import '../../core/contexto_instalacoes.dart';
import '../../core/erros.dart';
import '../../core/estado_ui.dart';
import '../../core/localidades.dart';
import '../../core/versoes.dart';
import '../../core/widgets/widgets.dart';
import '../../models/cliente.dart';
import '../../models/licenca.dart';
import '../../models/pedido_ajuda.dart';
import '../../models/pedido_renovacao.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';
import '../ativacao/ativar_instalacao_screen.dart';
import '../auth/login_screen.dart';
import '../instalacoes/detalhe_cliente_screen.dart';
import '../pedidos_ajuda/pedidos_ajuda_screen.dart';
import '../sobre/sobre_screen.dart';
import '../sugestoes/sugestoes_screen.dart';
import '../../main.dart' show dashboardRefreshProvider;

class _DashboardData {
  final List<Licenca> licencas;
  final List<Licenca> aExpirar;
  final List<PedidoRenovacao> pedidosPendentes;
  final List<PedidoAjuda> pedidosAjuda;
  final int sugestoesPorLer;
  final List<Ping> actividade;
  final List<Ping> novasInstalacoes;
  final List<Cliente> clientes;
  final ContextoInstalacoes ctx;
  final String versaoApp;

  _DashboardData({
    required this.licencas,
    required this.aExpirar,
    required this.pedidosPendentes,
    required this.pedidosAjuda,
    required this.sugestoesPorLer,
    required this.actividade,
    required this.novasInstalacoes,
    required this.clientes,
    required this.ctx,
    required this.versaoApp,
  });

  int get totalActivas =>
      licencas.where((l) => l.estado == EstadoLicenca.activa).length;
  int get totalAExpirar =>
      licencas.where((l) => l.estado == EstadoLicenca.aExpirar).length;
  int get totalExpiradas =>
      licencas.where((l) => l.estado == EstadoLicenca.expirada).length;
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late Future<_DashboardData> _future;
  StreamSubscription<void>? _refreshSub;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
    // Recarrega quando chega um push relevante (o Dashboard fica montado no
    // IndexedStack mesmo noutra tab, por isso actualiza em segundo plano).
    _refreshSub = ref.read(dashboardRefreshProvider).listen((_) {
      if (mounted) _recarregar();
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  Future<_DashboardData> _carregar() async {
    final licencasRepo = ref.read(licencasRepoProvider);
    final pedidosRepo = ref.read(pedidosRepoProvider);
    final ajudaRepo = ref.read(pedidosAjudaRepoProvider);
    final pingsRepo = ref.read(pingsRepoProvider);
    final clientesRepo = ref.read(clientesRepoProvider);

    final licencas = licencasRepo.listar();
    final aExpirar = licencasRepo.aExpirar();
    final pendentes = pedidosRepo.pendentes();
    final ajuda = ajudaRepo.listarAbertos();
    final sugestoes = ref.read(sugestoesRepoProvider).listarPorLer();
    final actividade = pingsRepo.ultimosPorInstalacao();
    final comLicenca = licencasRepo.machineIdsComLicenca();
    final clientes = clientesRepo.listar();
    final info = PackageInfo.fromPlatform();
    await Future.wait([
      licencas,
      aExpirar,
      pendentes,
      ajuda,
      sugestoes,
      actividade,
      comLicenca,
      clientes,
      info,
    ]);

    final acts = await actividade;
    final comLic = await comLicenca;
    final novas = acts.where((p) => !comLic.contains(p.machineId)).toList();
    final pkg = await info;

    developer.log(
      'licencas=${(await licencas).length}, novas=${novas.length}, '
      'pedidosAjuda=${(await ajuda).length}, pendentes=${(await pendentes).length}, '
      'actividade=${acts.length}, sugestoes=${(await sugestoes).length}',
      name: 'dashboard',
    );

    return _DashboardData(
      licencas: await licencas,
      aExpirar: await aExpirar,
      pedidosPendentes: await pendentes,
      pedidosAjuda: await ajuda,
      sugestoesPorLer: (await sugestoes).length,
      actividade: acts,
      novasInstalacoes: novas,
      clientes: await clientes,
      ctx: ContextoInstalacoes.build(
        clientes: await clientes,
        licencas: await licencas,
        pings: acts,
      ),
      versaoApp: pkg.version,
    );
  }

  Future<void> _recarregar() async {
    setState(() => _future = _carregar());
    await _future;
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _abrirDetalhe(String machineId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DetalheClienteScreen(machineId: machineId),
          ),
        )
        .then((_) => _recarregar());
  }

  void _abrirAtivacao(Ping p) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => AtivarInstalacaoScreen(ping: p)),
        )
        .then((_) => _recarregar());
  }

  void _abrirPedidosAjuda() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PedidosAjudaScreen()))
        .then((_) => _recarregar());
  }

  void _abrirSugestoes() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SugestoesScreen()))
        .then((_) => _recarregar());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: AppSpacing.lg,
        title: const _Wordmark(),
        actions: [
          IconButton(
            iconSize: 20,
            icon: const Icon(Icons.refresh),
            onPressed: _recarregar,
          ),
          IconButton(
            iconSize: 20,
            icon: const Icon(Icons.info_outline),
            tooltip: 'Sobre / Sistema',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SobreScreen())),
          ),
          IconButton(
            iconSize: 20,
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErroView(erro: snapshot.error!, onRetry: _recarregar);
          }
          final data = snapshot.data!;
          final classV = ClassificadorVersoes(
            data.actividade.map((p) => p.versao),
          );
          return RefreshIndicator(
            onRefresh: _recarregar,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _KpiRow(data: data),
                const SizedBox(height: AppSpacing.lg),

                if (data.novasInstalacoes.isNotEmpty) ...[
                  WiSeccaoTitulo(
                    titulo:
                        'Início de actividade (${data.novasInstalacoes.length})',
                    icone: Icons.fiber_new_outlined,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...data.novasInstalacoes.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _CardNovaInstalacao(
                        ping: p,
                        onAtivar: () => _abrirAtivacao(p),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                if (data.pedidosAjuda.isNotEmpty) ...[
                  WiSeccaoTitulo(
                    titulo: 'Pedidos de ajuda (${data.pedidosAjuda.length})',
                    icone: Icons.help_outline,
                    comChevron: true,
                    onTap: _abrirPedidosAjuda,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...data.pedidosAjuda
                      .take(2)
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _CardPedidoAjuda(
                            pedido: p,
                            ctx: data.ctx,
                            onAbrir: _abrirPedidosAjuda,
                          ),
                        ),
                      ),
                  if (data.pedidosAjuda.length > 2)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _abrirPedidosAjuda,
                        child: Text('Ver todos (${data.pedidosAjuda.length})'),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                if (data.sugestoesPorLer > 0) ...[
                  WiSeccaoTitulo(
                    titulo: 'Sugestões (${data.sugestoesPorLer})',
                    icone: Icons.lightbulb_outline,
                    comChevron: true,
                    onTap: _abrirSugestoes,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  WiCardDestaque(
                    cor: AppColors.roxo500,
                    onTap: _abrirSugestoes,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb,
                          color: AppColors.roxo700,
                          size: 22,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '${data.sugestoesPorLer} sugestão(ões) por ler',
                            style: AppText.bodyStrong,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                if (data.aExpirar.isNotEmpty) ...[
                  const WiSeccaoTitulo(
                    titulo: 'A expirar nos próximos 15 dias',
                    icone: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...data.aExpirar.map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _CardLicenca(
                        licenca: l,
                        ctx: data.ctx,
                        onTap: () => _abrirDetalhe(l.machineId),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                if (data.pedidosPendentes.isNotEmpty) ...[
                  const WiSeccaoTitulo(
                    titulo: 'Pedidos de renovação',
                    icone: Icons.autorenew,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...data.pedidosPendentes.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _CardPedidoRenovacao(
                        pedido: p,
                        onVer: () => _abrirDetalhe(p.machineId),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                const WiSeccaoTitulo(
                  titulo: 'Actividade recente',
                  comChevron: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                _CardActividade(
                  pings: data.actividade.take(5).toList(),
                  ctx: data.ctx,
                  classV: classV,
                  onTap: _abrirDetalhe,
                ),

                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Text(
                    '${Config.marca} Control · v${data.versaoApp}',
                    style: AppText.caption,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_laundry_service, size: 22, color: Colors.white),
        const SizedBox(width: AppSpacing.sm),
        const Text(
          'WashInvoice',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 6),
        Text(
          'CONTROL',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 2,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  final _DashboardData data;
  const _KpiRow({required this.data});

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight é obrigatório: sem ele, `CrossAxisAlignment.stretch` num
    // Row dentro do ListView (altura máxima infinita) força a Row a altura
    // infinita — em release renderiza os KPIs seguidos de espaço morto enorme,
    // empurrando as secções para fora do ecrã. O IntrinsicHeight limita o eixo
    // vertical à altura do card mais alto, mantendo os 4 KPIs com igual altura.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: WiKpiCard(
              icone: Icons.check_circle,
              valor: data.totalActivas,
              label: 'Activas',
              cor: AppColors.verde,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: WiKpiCard(
              icone: Icons.warning_amber_rounded,
              valor: data.totalAExpirar,
              label: 'A expirar',
              cor: AppColors.laranja,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: WiKpiCard(
              icone: Icons.highlight_off,
              valor: data.totalExpiradas,
              label: 'Expiradas',
              cor: AppColors.vermelho,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: WiKpiCard(
              icone: Icons.pending_actions,
              valor: data.pedidosPendentes.length,
              label: 'Pendentes',
              cor: AppColors.roxo,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardNovaInstalacao extends StatelessWidget {
  final Ping ping;
  final VoidCallback onAtivar;
  const _CardNovaInstalacao({required this.ping, required this.onAtivar});

  @override
  Widget build(BuildContext context) {
    final tempo = timeago.format(ping.criadoEm, locale: 'pt');
    final cidade = Localidades.traduzir(ping.cidade);
    final localidade = cidade.isEmpty ? 'Localização desconhecida' : cidade;
    return WiCardDestaque(
      cor: AppColors.azul500,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (ping.nif != null && ping.nif!.trim().isNotEmpty)
                      ? 'NIF ${ping.nif!.trim()}'
                      : 'Sem NIF ainda',
                  style: AppText.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(
                  '$localidade · v${ping.versao ?? '?'} · há $tempo',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: onAtivar,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.azul700,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
            ),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
  }
}

class _CardPedidoAjuda extends StatelessWidget {
  final PedidoAjuda pedido;
  final ContextoInstalacoes ctx;
  final VoidCallback onAbrir;
  const _CardPedidoAjuda({
    required this.pedido,
    required this.ctx,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final tempo = timeago.format(pedido.criadoEm, locale: 'pt');
    final cliente = ctx.clienteDe(
      clienteId: pedido.clienteId,
      machineId: pedido.machineId,
      nif: pedido.nif,
    );
    final telefone = cliente?.telemovel;
    return WiCardDestaque(
      cor: AppColors.laranja500,
      onTap: onAbrir,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.help, color: AppColors.laranja700, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.nomeDe(machineId: pedido.machineId, nif: pedido.nif),
                  style: AppText.bodyStrong,
                ),
                // Linha 2 = preview das notas (mais útil que Sinal−Localidade,
                // que caía em "? − " quando o pedido chega sem ping associado).
                if (pedido.notas != null &&
                    pedido.notas!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    pedido.notas!.trim(),
                    style: AppText.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                Text(
                  'há $tempo${telefone != null ? ' · $telefone' : ''}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          if (telefone != null)
            IconButton(
              icon: const Icon(Icons.phone, color: AppColors.azul700),
              onPressed: () => Acoes.ligarPara(telefone),
            ),
        ],
      ),
    );
  }
}

class _CardLicenca extends StatelessWidget {
  final Licenca licenca;
  final ContextoInstalacoes ctx;
  final VoidCallback onTap;
  const _CardLicenca({
    required this.licenca,
    required this.ctx,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final validade = timeago.format(
      licenca.validade,
      locale: 'pt',
      allowFromNow: true,
    );
    return WiCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      onTap: onTap,
      child: Row(
        children: [
          BadgeEstado(licenca.estado),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.nomeDe(machineId: licenca.machineId, nif: licenca.nif),
                  style: AppText.bodyStrong,
                ),
                Text(
                  '${licenca.planoLabel} · expira $validade',
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

class _CardPedidoRenovacao extends StatelessWidget {
  final PedidoRenovacao pedido;
  final VoidCallback onVer;
  const _CardPedidoRenovacao({required this.pedido, required this.onVer});

  @override
  Widget build(BuildContext context) {
    return WiCardDestaque(
      cor: AppColors.roxo500,
      onTap: onVer,
      child: Row(
        children: [
          const Icon(Icons.autorenew, color: AppColors.roxo700, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NIF ${pedido.nif}', style: AppText.bodyStrong),
                Text(
                  'Quer renovar: ${pedido.planoDesejado} · ${timeago.format(pedido.criadoEm, locale: 'pt')}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onVer,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.roxo700,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
            ),
            child: const Text('Ver'),
          ),
        ],
      ),
    );
  }
}

class _CardActividade extends StatelessWidget {
  final List<Ping> pings;
  final ContextoInstalacoes ctx;
  final ClassificadorVersoes classV;
  final void Function(String machineId) onTap;
  const _CardActividade({
    required this.pings,
    required this.ctx,
    required this.classV,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (pings.isEmpty) {
      return const WiCard(
        child: Text('Sem actividade recente.', style: AppText.body),
      );
    }
    return WiCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < pings.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.borda),
            _LinhaActividade(
              ping: pings[i],
              ctx: ctx,
              estadoVersao: classV.estadoDe(pings[i].versao),
              onTap: () => onTap(pings[i].machineId),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaActividade extends StatelessWidget {
  final Ping ping;
  final ContextoInstalacoes ctx;
  final EstadoVersao estadoVersao;
  final VoidCallback onTap;
  const _LinhaActividade({
    required this.ping,
    required this.ctx,
    required this.estadoVersao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cliente = ctx.clienteDe(machineId: ping.machineId, nif: ping.nif);
    final cidade = Localidades.traduzir(ping.cidade);
    final localidade =
        (cliente?.localidade != null && cliente!.localidade!.trim().isNotEmpty)
        ? cliente.localidade!.trim()
        : (cidade.isEmpty ? '—' : cidade);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 10,
              color: ping.cidade != null
                  ? AppColors.verde
                  : AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ctx.nomeDe(machineId: ping.machineId, nif: ping.nif),
                    style: AppText.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(localidade, style: AppText.caption),
                ],
              ),
            ),
            VersaoBadge(versao: ping.versao, estado: estadoVersao),
            const SizedBox(width: AppSpacing.sm),
            Text(
              timeago.format(ping.criadoEm, locale: 'pt'),
              style: AppText.caption,
            ),
          ],
        ),
      ),
    );
  }
}
