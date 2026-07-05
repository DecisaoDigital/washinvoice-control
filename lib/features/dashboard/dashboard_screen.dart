import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/app_colors.dart';
import '../../core/erros.dart';
import '../../core/estado_ui.dart';
import '../../core/versoes.dart';
import '../../models/licenca.dart';
import '../../models/pedido_renovacao.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';
import '../ativacao/ativar_instalacao_screen.dart';
import '../auth/login_screen.dart';
import '../instalacoes/detalhe_cliente_screen.dart';

class _DashboardData {
  final List<Licenca> licencas;
  final List<Licenca> aExpirar;
  final List<PedidoRenovacao> pedidosPendentes;
  final List<Ping> actividade;
  final List<Ping> novasInstalacoes;

  _DashboardData({
    required this.licencas,
    required this.aExpirar,
    required this.pedidosPendentes,
    required this.actividade,
    required this.novasInstalacoes,
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

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<_DashboardData> _carregar() async {
    final licencasRepo = ref.read(licencasRepoProvider);
    final pedidosRepo = ref.read(pedidosRepoProvider);
    final pingsRepo = ref.read(pingsRepoProvider);

    final results = await Future.wait([
      licencasRepo.listar(),
      licencasRepo.aExpirar(),
      pedidosRepo.pendentes(),
      pingsRepo.ultimosPorInstalacao(),
      licencasRepo.machineIdsComLicenca(),
    ]);

    final actividade = results[3] as List<Ping>;
    final comLicenca = results[4] as Set<String>;
    // Instalações novas: máquinas a comunicar que ainda não têm licença.
    final novas =
        actividade.where((p) => !comLicenca.contains(p.machineId)).toList();

    return _DashboardData(
      licencas: results[0] as List<Licenca>,
      aExpirar: results[1] as List<Licenca>,
      pedidosPendentes: results[2] as List<PedidoRenovacao>,
      actividade: actividade,
      novasInstalacoes: novas,
    );
  }

  Future<void> _recarregar() async {
    setState(() {
      _future = _carregar();
    });
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

  void _abrirDetalhe(String nif) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => DetalheClienteScreen(nif: nif)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WashInvoice Control'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _recarregar),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
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
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CardResumo(
                        titulo: 'Activas',
                        valor: data.totalActivas,
                        cor: AppColors.verde,
                        icone: Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CardResumo(
                        titulo: 'A expirar (≤15d)',
                        valor: data.totalAExpirar,
                        cor: AppColors.laranja,
                        icone: Icons.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CardResumo(
                        titulo: 'Expiradas',
                        valor: data.totalExpiradas,
                        cor: AppColors.vermelho,
                        icone: Icons.cancel,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CardResumo(
                        titulo: 'Pendentes',
                        valor: data.pedidosPendentes.length,
                        cor: AppColors.roxo,
                        icone: Icons.pending,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (data.aExpirar.isNotEmpty) ...[
                  const _SeccaoTitulo('A expirar nos próximos 15 dias'),
                  ...data.aExpirar.map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LinhaLicenca(l, onTap: () => _abrirDetalhe(l.nif)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (data.pedidosPendentes.isNotEmpty) ...[
                  const _SeccaoTitulo('Pedidos de renovação'),
                  ...data.pedidosPendentes.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LinhaPedido(p, onVer: () => _abrirDetalhe(p.nif)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (data.novasInstalacoes.isNotEmpty) ...[
                  _SeccaoTitulo(
                    'Início de atividade (${data.novasInstalacoes.length})',
                  ),
                  ...data.novasInstalacoes.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LinhaNovaInstalacao(
                        p,
                        onAtivar: () => _abrirAtivacao(p),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const _SeccaoTitulo('Actividade recente'),
                ...data.actividade.take(5).map(
                      (p) => _LinhaActividade(
                        p,
                        estadoVersao: classV.estadoDe(p.versao),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CardResumo extends StatelessWidget {
  final String titulo;
  final int valor;
  final Color cor;
  final IconData icone;

  const _CardResumo({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor, size: 20),
          const SizedBox(height: 6),
          Text(
            valor.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
          ),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccaoTitulo extends StatelessWidget {
  final String texto;
  const _SeccaoTitulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _LinhaLicenca extends StatelessWidget {
  final Licenca licenca;
  final VoidCallback onTap;
  const _LinhaLicenca(this.licenca, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: BadgeEstado(licenca.estado),
        title: Text(licenca.nome ?? licenca.nif),
        subtitle: Text(
          'Expira ${timeago.format(licenca.validade, locale: 'pt', allowFromNow: true)} · ${licenca.plano}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: onTap,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _LinhaPedido extends StatelessWidget {
  final PedidoRenovacao pedido;
  final VoidCallback onVer;
  const _LinhaPedido(this.pedido, {required this.onVer});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.roxo.withValues(alpha: 0.08),
      child: ListTile(
        leading: const Icon(Icons.pending, color: AppColors.roxo),
        title: Text(pedido.nif),
        subtitle: Text(
          'Quer renovar: ${pedido.planoDesejado} · ${timeago.format(pedido.criadoEm, locale: 'pt')}',
        ),
        trailing: FilledButton(
          onPressed: onVer,
          style: FilledButton.styleFrom(backgroundColor: AppColors.roxo),
          child: const Text('Ver'),
        ),
      ),
    );
  }
}

class _LinhaNovaInstalacao extends StatelessWidget {
  final Ping ping;
  final VoidCallback onAtivar;
  const _LinhaNovaInstalacao(this.ping, {required this.onAtivar});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.azul.withValues(alpha: 0.07),
      child: ListTile(
        leading: const Icon(Icons.fiber_new, color: AppColors.azul),
        title: Text(ping.nif ?? ping.machineId),
        subtitle: Text(
          '${ping.cidade ?? 'Localização desconhecida'} · v${ping.versao ?? '?'} · '
          '${timeago.format(ping.criadoEm, locale: 'pt')}',
        ),
        trailing: FilledButton(
          onPressed: onAtivar,
          style: FilledButton.styleFrom(backgroundColor: AppColors.azul),
          child: const Text('Ativar'),
        ),
      ),
    );
  }
}

class _LinhaActividade extends StatelessWidget {
  final Ping ping;
  final EstadoVersao estadoVersao;
  const _LinhaActividade(this.ping, {required this.estadoVersao});

  @override
  Widget build(BuildContext context) {
    final titulo = ping.nif ??
        (ping.machineId.length > 8
            ? '${ping.machineId.substring(0, 8)}...'
            : ping.machineId);
    return ListTile(
      leading: Icon(
        Icons.circle,
        size: 10,
        color: ping.cidade != null ? AppColors.verde : AppColors.textTertiary,
      ),
      title: Text(titulo),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              ping.cidade ?? 'Localização desconhecida',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          VersaoBadge(versao: ping.versao, estado: estadoVersao),
        ],
      ),
      trailing: Text(
        timeago.format(ping.criadoEm, locale: 'pt'),
        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
      ),
    );
  }
}
