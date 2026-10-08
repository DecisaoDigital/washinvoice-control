import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/dates.dart';
import '../../../core/erros.dart';
import '../../../core/widgets/widgets.dart';
import '../../../repositories/providers.dart';
import '../../../repositories/punho_admin_repository.dart';
import '../confirmar_apagar_pedido.dart';
import 'decidir_pedido_fist.dart';
import 'fist_pendentes_provider.dart';
import 'punho_decidir_modal.dart';
import 'punho_empresas_screen.dart';

/// Ticker que pede ao [FistPedidosScreen] para ir buscar os dados outra vez.
///
/// Existe por causa do `IndexedStack` do `HomeShell`: as páginas dos separadores
/// ficam montadas para sempre, o `initState` corre uma única vez e mudar de
/// separador não desmonta nada. Sem este sinal, entrar em "Fist" mostrava a
/// lista tal como estava na primeira montagem — pedidos já decididos ou até
/// já apagados continuavam à vista.
///
/// Incrementar = "os dados podem estar velhos". Quem incrementa: o `HomeShell`,
/// ao entrar no separador e ao aterrar aqui vindo de um push.
final punhoPedidosRefreshProvider = StateProvider<int>((_) => 0);

/// Pedidos de acesso à app **Fist**, decididos à mão pelo admin global.
///
/// Distinto de `PedidosAcessoScreen`, que trata dos acessos ao próprio Control:
/// aqui são utilizadores de uma app cliente, com empresas e convites próprios.
///
/// O selector multi-app da AppBar (`appFilterProvider`) **não se aplica** a este
/// ecrã: é sempre Fist, por definição. Por isso não é observado em lado nenhum
/// deste ficheiro.
class FistPedidosScreen extends ConsumerStatefulWidget {
  const FistPedidosScreen({super.key});

  @override
  ConsumerState<FistPedidosScreen> createState() => _FistPedidosScreenState();
}

class _FistPedidosScreenState extends ConsumerState<FistPedidosScreen>
    with WidgetsBindingObserver {
  String _estado = 'pendente';
  late Future<_Dados> _future;
  bool _aDecidir = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recarregar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Voltar ao Control depois de ler um push noutra app é o momento em que os
  /// dados à vista têm mais probabilidade de já não existirem na base.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) recarregarSePreciso();
  }

  /// Recarrega, excepto a meio de uma decisão: trocar o future debaixo de uma
  /// RPC em curso só dava um pisca-pisca e escondia o resultado que aí vem.
  void recarregarSePreciso() {
    if (!mounted || _aDecidir) return;
    setState(_recarregar);
  }

  void _recarregar() {
    _future = _carregar();
  }

  Future<_Dados> _carregar() async {
    final repo = ref.read(punhoAdminRepoProvider);
    final r = await Future.wait([
      repo.listarPedidos(estado: _estado),
      repo.listarEmpresas(),
    ]);
    return _Dados(r[0] as List<FistPedido>, r[1] as List<FistEmpresa>);
  }

  Future<void> _abrirDecisao(FistPedido pedido, List<FistEmpresa> empresas) async {
    final ok = await abrirDecisaoFist(
      context,
      ref,
      pedido,
      empresas,
      aOcupar: _ocupar,
    );
    if (ok && mounted) setState(_recarregar);
  }

  /// Feedback visível enquanto a RPC corre — a decisão escreve em várias
  /// tabelas e pode demorar.
  void _ocupar(bool v) {
    if (mounted) setState(() => _aDecidir = v);
  }

  Future<void> _abrirRevogacao(FistPedido pedido) async {
    final escolha = await showDialog<DecisaoFist>(
      context: context,
      builder: (_) => FistRevogarModal(pedido: pedido),
    );
    if (escolha != null) await _aplicar(pedido, escolha);
  }

  Future<void> _apagar(FistPedido pedido) async {
    final confirmado = await confirmarApagarPedido(
      context,
      quem: pedido.nomeApresentavel,
      email: pedido.email,
      estado: pedido.estado,
    );
    if (!confirmado || !mounted) return;

    setState(() => _aDecidir = true);
    try {
      await ref.read(punhoAdminRepoProvider).apagar(pedido.id);
      if (!mounted) return;
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Pedido de ${pedido.nomeApresentavel} apagado.'),
        ),
      );
      ref.invalidate(fistPendentesProvider);
      setState(_recarregar);
    } catch (e) {
      if (mounted) mostrarErro(e);
    } finally {
      if (mounted) setState(() => _aDecidir = false);
    }
  }

  Future<void> _aplicar(FistPedido pedido, DecisaoFist escolha) async {
    final ok = await aplicarDecisaoFist(ref, pedido, escolha, aOcupar: _ocupar);
    if (ok && mounted) setState(_recarregar);
  }

  @override
  Widget build(BuildContext context) {
    // Entrada no separador / aterragem vinda de um push.
    ref.listen<int>(
      punhoPedidosRefreshProvider,
      (_, __) => recarregarSePreciso(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos Fist'),
        actions: [
          IconButton(
            tooltip: 'Empresas',
            icon: const Icon(Icons.apartment),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FistEmpresasScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Recarregar',
            icon: const Icon(Icons.refresh),
            onPressed: _aDecidir ? null : () => setState(_recarregar),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_aDecidir) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final estado in punhoEstados)
                  WiChipFiltro(
                    label: _rotuloEstado(estado),
                    activo: _estado == estado,
                    onTap: _aDecidir
                        ? null
                        : () => setState(() {
                            _estado = estado;
                            _recarregar();
                          }),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<_Dados>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return ErroView(
                    erro: snap.error!,
                    onRetry: () => setState(_recarregar),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final dados = snap.data!;
                if (dados.pedidos.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text('Não há pedidos ${_rotuloEstado(_estado).toLowerCase()}.'),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_recarregar);
                    await _future;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: dados.pedidos.length,
                    itemBuilder: (_, i) => _PedidoCard(
                      pedido: dados.pedidos[i],
                      ocupado: _aDecidir,
                      onDecidir: () => _abrirDecisao(dados.pedidos[i], dados.empresas),
                      onRevogar: () => _abrirRevogacao(dados.pedidos[i]),
                      onApagar: () => _apagar(dados.pedidos[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _rotuloEstado(String estado) => switch (estado) {
  'pendente' => 'Pendentes',
  'aprovado' => 'Aprovados',
  'recusado' => 'Recusados',
  _ => 'Revogados',
};

class _Dados {
  final List<FistPedido> pedidos;
  final List<FistEmpresa> empresas;
  _Dados(this.pedidos, this.empresas);
}

class _PedidoCard extends StatelessWidget {
  const _PedidoCard({
    required this.pedido,
    required this.ocupado,
    required this.onDecidir,
    required this.onRevogar,
    required this.onApagar,
  });

  final FistPedido pedido;
  final bool ocupado;
  final VoidCallback onDecidir, onRevogar, onApagar;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final aprovado = p.estado == 'aprovado';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.nomeApresentavel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _BadgeOrigem(porConvite: p.porConvite),
              ],
            ),
            Text(p.email),
            const SizedBox(height: AppSpacing.sm),
            Text('Organização indicada: ${p.organizacaoIndicada}'),
            Text('Cargo pretendido: ${p.perfilApresentavel}'),
            Text('Pedido em ${Dates.data(p.criadoEm)}'),
            // De que terminal veio. É a mesma leitura que Instalações faz para
            // o WashInvoice, agora pela mesma chave `(machine_id, app)`. Sem
            // isto, um pedido era só um email — e a decisão de aprovar não
            // tinha como se ancorar num aparelho.
            if (p.maquinaApresentavel != null)
              Text(
                'Terminal: ${p.maquinaApresentavel}'
                '${p.maquinaVersao == null ? '' : ' · ${p.app} ${p.maquinaVersao}'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            if (p.porConvite && p.conviteEmpresaNome != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Convite da empresa ${p.conviteEmpresaNome}'
                  '${p.conviteCriadoEm == null ? '' : ' · emitido em ${Dates.data(p.conviteCriadoEm!)}'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (aprovado && p.empresaNome != null)
              Text('Empresa: ${p.empresaNome}'),
            const SizedBox(height: AppSpacing.md),
            // A acção da linha à esquerda, o apagar afastado à direita: são
            // de naturezas diferentes e não devem ficar lado a lado, onde o
            // dedo que ia para "Decidir" acerta no que não tem volta.
            Row(
              children: [
                if (aprovado)
                  OutlinedButton(
                    onPressed: ocupado ? null : onRevogar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.vermelho,
                    ),
                    child: const Text('Revogar'),
                  )
                else if (p.estado == 'pendente')
                  FilledButton(
                    onPressed: ocupado ? null : onDecidir,
                    child: const Text('Decidir'),
                  )
                else
                  // Recusado ou revogado: reabrir é aprovar, e isso passa pelo
                  // mesmo diálogo.
                  OutlinedButton(
                    onPressed: ocupado ? null : onDecidir,
                    child: const Text('Reabrir'),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Apagar pedido',
                  onPressed: ocupado ? null : onApagar,
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeOrigem extends StatelessWidget {
  const _BadgeOrigem({required this.porConvite});
  final bool porConvite;

  @override
  Widget build(BuildContext context) {
    final cor = porConvite ? AppColors.azul700 : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: cor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        porConvite ? 'CONVITE' : 'LIVRE',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
          color: cor,
        ),
      ),
    );
  }
}
