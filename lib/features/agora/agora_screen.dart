import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/acoes.dart';
import '../../core/app_colors.dart';
import '../../core/app_filter/app_filter_provider.dart';
import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/erros.dart';
import '../../core/widgets/widgets.dart';
import '../../main.dart' show dashboardRefreshProvider;
import '../../repositories/providers.dart';
import '../acessos/punho/decidir_pedido_fist.dart';
import '../acessos/punho/punho_pedidos_screen.dart';
import '../ativacao/ativar_instalacao_screen.dart';
import '../instalacoes/detalhe_cliente_screen.dart';
import '../instalacoes/renovar_licenca.dart';
import '../pedidos_site/envelope_pedidos_site.dart';
import '../pedidos_ajuda/detalhe_pedido_ajuda_screen.dart';
import '../pedidos_ajuda/resolver_pedido_ajuda.dart';
import '../sugestoes/detalhe_sugestao_screen.dart';
import 'agora_modelo.dart';
import 'agora_providers.dart';

/// «Agora»: tudo o que está à espera do Cesar, numa só fila, por urgência.
///
/// Em vez de ir ao Resumo, às Sugestões, aos Pedidos de ajuda e aos Pedidos
/// Fist ver se há alguma coisa, há uma lista só — e cada cartão traz UM botão
/// com o que se faz a seguir. Não tem lógica de negócio própria: os botões
/// abrem os fluxos que já existem (ver `_Accoes`).
class AgoraScreen extends ConsumerStatefulWidget {
  const AgoraScreen({super.key});

  @override
  ConsumerState<AgoraScreen> createState() => _AgoraScreenState();
}

class _AgoraScreenState extends ConsumerState<AgoraScreen>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _pushSub;

  /// Itens com uma acção a decorrer — trava o duplo toque no mesmo cartão.
  final Set<String> _ocupados = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Push em primeiro plano → fila nova. O ecrã fica montado no IndexedStack
    // mesmo noutro separador, por isso actualiza (e o badge com ele).
    _pushSub = ref.read(dashboardRefreshProvider).listen((_) => _refrescar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushSub?.cancel();
    super.dispose();
  }

  /// Voltar à app depois de atender um cliente é quando a fila mais
  /// provavelmente mudou.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refrescar();
  }

  void _refrescar() {
    if (!mounted) return;
    ref.read(agoraRefreshProvider.notifier).state++;
  }

  Future<void> _recarregar() async {
    _refrescar();
    try {
      await ref.read(agoraProvider.future);
    } catch (_) {
      // O erro já aparece no corpo do ecrã, com «Tentar de novo».
    }
  }

  /// Abre [ecra] por cima e refresca a fila quando se volta.
  Future<void> _abrir(Widget ecra) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ecra));
    _refrescar();
  }

  /// Corre [accao] com o item marcado como ocupado.
  Future<void> _comTrava(ItemAgora i, Future<void> Function() accao) async {
    if (!_ocupados.add(i.chave)) return;
    setState(() {});
    try {
      await accao();
    } finally {
      _ocupados.remove(i.chave);
      if (mounted) setState(() {});
    }
  }

  // ── Corpo do cartão: abre o detalhe que já existe ─────────────────────────
  void _abrirDetalhe(ItemAgora i) => switch (i.tipo) {
    TipoAgora.expirada || TipoAgora.aExpirar || TipoAgora.renovacao => _abrir(
      DetalheClienteScreen(machineId: i.machineId!),
    ),
    // Um terminal novo ainda não tem licença: não há ficha, só a activação.
    TipoAgora.terminalNovo => _abrir(AtivarInstalacaoScreen(ping: i.ping!)),
    TipoAgora.ajuda => _abrir(DetalhePedidoAjudaScreen(pedido: i.pedidoAjuda!)),
    TipoAgora.acessoFist => _abrir(const FistPedidosScreen()),
    TipoAgora.sugestao => _abrir(DetalheSugestaoScreen(sugestao: i.sugestao!)),
  };

  // ── Botão primário ────────────────────────────────────────────────────────
  void _accaoPrimaria(ItemAgora i) => switch (i.tipo) {
    // «Renovar» abre a ficha já com o selector da nova validade.
    TipoAgora.expirada || TipoAgora.aExpirar => _comTrava(i, () => _renovar(i)),
    TipoAgora.acessoFist => _comTrava(i, () => _decidirFist(i)),
    TipoAgora.terminalNovo => _abrir(AtivarInstalacaoScreen(ping: i.ping!)),
    TipoAgora.renovacao => _abrir(
      DetalheClienteScreen(machineId: i.machineId!),
    ),
    TipoAgora.sugestao => _abrir(DetalheSugestaoScreen(sugestao: i.sugestao!)),
    // O ajuda tem dois botões (Ligar, Resolvido): ver `_Cartao`.
    TipoAgora.ajuda => null,
  };

  /// «Renovar» sem abrir a ficha: bottom sheet com as durações habituais.
  Future<void> _renovar(ItemAgora i) async {
    final l = i.licenca!;
    try {
      // Se o cliente também pediu renovação, fica confirmado com esta.
      final pedido = await ref
          .read(pedidosRepoProvider)
          .pendentePorNif(l.nif, app: l.app);
      if (!mounted) return;
      await renovarLicencaComSheet(
        context,
        ref,
        l,
        pedido: pedido,
        quem: i.titulo,
        depois: () async {
          if (mounted) await _recarregar();
        },
      );
    } catch (e, st) {
      mostrarErro(e, stack: st);
    }
  }

  Future<void> _decidirFist(ItemAgora i) async {
    try {
      // As empresas só se pedem quando o modal vai abrir (escolher empresa de
      // destino); a fila não as carrega à toa.
      final empresas = await ref.read(punhoAdminRepoProvider).listarEmpresas();
      if (!mounted) return;
      await abrirDecisaoFist(context, ref, i.fistPedido!, empresas);
    } catch (e, st) {
      mostrarErro(e, stack: st);
    }
    _refrescar();
  }

  Future<void> _resolver(ItemAgora i) => _comTrava(
    i,
    () => resolverPedidoAjuda(
      ref,
      i.pedidoAjuda!,
      depois: () async {
        if (mounted) await _recarregar();
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final filtro = ref.watch(appFilterProvider);
    final agora = ref.watch(agoraProvider);
    final escolhido = ref.watch(agoraTipoFiltroProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Agora', style: TextStyle(fontSize: 18)),
            // Explícito: uma fila filtrada que pareça completa leva a achar
            // que não há nada pendente.
            Text(
              'a ver: ${_nomeDoFiltro(filtro)}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: const [
          EnvelopePedidosSite(),
          WiAppSelector(),
          SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: WiComPastilhaApp(
        corpo: agora.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErroView(erro: e, onRetry: _recarregar),
          data: (data) {
            final contagem = data.contagem;
            // Se o tipo escolhido esvaziou (resolveu-se o último), volta a
            // mostrar tudo em vez de uma lista vazia que parece um erro.
            final tipo = (escolhido != null && (contagem[escolhido] ?? 0) > 0)
                ? escolhido
                : null;
            final visiveis = tipo == null
                ? data.itens
                : data.itens.where((i) => i.tipo == tipo).toList();
            return Column(
              children: [
                if (data.itens.isNotEmpty)
                  _Chips(
                    total: data.itens.length,
                    contagem: contagem,
                    escolhido: tipo,
                    onEscolher: (t) =>
                        ref.read(agoraTipoFiltroProvider.notifier).state = t,
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _recarregar,
                    child: visiveis.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              WiEmptyState(
                                icone: Icons.check_circle_outline,
                                titulo: 'Nada pendente',
                                mensagem: 'Nenhum cliente está à tua espera.',
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.sm,
                              AppSpacing.lg,
                              AppSpacing.lg,
                            ),
                            itemCount: visiveis.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, n) {
                              final i = visiveis[n];
                              return _Cartao(
                                key: ValueKey(i.chave),
                                item: i,
                                ocupado: _ocupados.contains(i.chave),
                                onAbrir: () => _abrirDetalhe(i),
                                onPrimaria: () => _accaoPrimaria(i),
                                onResolver: () => _resolver(i),
                              );
                            },
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

String _nomeDoFiltro(AppFiltro f) => switch (f) {
  AppFiltro.todas => 'Todas',
  _ => f.etiqueta,
};

/// Chips de contagem por tipo; tocar filtra a fila, tocar outra vez limpa.
class _Chips extends StatelessWidget {
  final int total;
  final Map<TipoAgora, int> contagem;
  final TipoAgora? escolhido;
  final ValueChanged<TipoAgora?> onEscolher;

  const _Chips({
    required this.total,
    required this.contagem,
    required this.escolhido,
    required this.onEscolher,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          WiChipFiltro(
            label: 'Todos ($total)',
            activo: escolhido == null,
            onTap: () => onEscolher(null),
          ),
          for (final t in TipoAgora.values)
            if ((contagem[t] ?? 0) > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              WiChipFiltro(
                label: '${t.chip} (${contagem[t]})',
                activo: escolhido == t,
                onTap: () => onEscolher(escolhido == t ? null : t),
              ),
            ],
        ],
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  final ItemAgora item;
  final bool ocupado;
  final VoidCallback onAbrir;
  final VoidCallback onPrimaria;
  final VoidCallback onResolver;

  const _Cartao({
    super.key,
    required this.item,
    required this.ocupado,
    required this.onAbrir,
    required this.onPrimaria,
    required this.onResolver,
  });

  /// Texto do botão primário (e ícone) de cada tipo.
  (String, IconData) get _primaria => switch (item.tipo) {
    TipoAgora.expirada ||
    TipoAgora.aExpirar => ('Renovar', Icons.event_available),
    TipoAgora.acessoFist => ('Decidir', Icons.how_to_reg_outlined),
    TipoAgora.terminalNovo => ('Activar', Icons.play_circle_outline),
    TipoAgora.renovacao => ('Ver pedido', Icons.autorenew),
    TipoAgora.sugestao => ('Ler', Icons.menu_book_outlined),
    TipoAgora.ajuda => ('Ligar', Icons.phone),
  };

  ButtonStyle _estilo(Color cor) => FilledButton.styleFrom(
    backgroundColor: cor,
    // Alvo de toque ≥ 48 dp.
    minimumSize: const Size(0, 48),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
  );

  @override
  Widget build(BuildContext context) {
    final t = item.tipo;
    final (rotuloPrimaria, iconePrimaria) = _primaria;
    return WiCardDestaque(
      cor: t.cor,
      onTap: onAbrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(t.icone, size: 18, color: t.corForte),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  t.etiqueta,
                  style: AppText.label.copyWith(color: t.corForte),
                ),
              ),
              WiAppBadgeAuto(item.app, espacoDireita: 0),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.titulo,
            style: AppText.bodyStrong,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(item.subtitulo(), style: AppText.caption),
          if (item.detalhe != null)
            Text(
              item.detalhe!,
              style: AppText.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: AppSpacing.md),
          // Acção na metade de baixo do cartão: é onde o polegar chega.
          if (t == TipoAgora.ajuda)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: item.telefone == null
                        ? null
                        : () => Acoes.ligarPara(item.telefone!),
                    icon: Icon(iconePrimaria, size: 18),
                    style: _estilo(AppColors.azul700),
                    label: const Text('Ligar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: ocupado ? null : onResolver,
                    icon: const Icon(Icons.check, size: 18),
                    style: _estilo(AppColors.verde700),
                    label: const Text('Resolvido'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: ocupado ? null : onPrimaria,
                icon: Icon(iconePrimaria, size: 18),
                style: _estilo(t.corForte),
                label: Text(rotuloPrimaria),
              ),
            ),
        ],
      ),
    );
  }
}
