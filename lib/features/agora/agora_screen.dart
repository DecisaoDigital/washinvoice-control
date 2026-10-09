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
import '../../repositories/historico_repository.dart';
import '../../repositories/providers.dart';
import '../../services/registo_accoes.dart';
import '../acessos/punho/decidir_pedido_fist.dart';
import '../acessos/punho/punho_decidir_modal.dart';
import '../ativacao/ativar_instalacao_screen.dart';
import '../instalacoes/detalhe_cliente_screen.dart';
import '../instalacoes/renovar_licenca.dart';
import '../nav/menu_control.dart';
import '../pedidos_site/envelope_pedidos_site.dart';
import '../pedidos_ajuda/detalhe_pedido_ajuda_screen.dart';
import '../pedidos_ajuda/resolver_pedido_ajuda.dart';
import '../sugestoes/detalhe_sugestao_screen.dart';
import 'agora_modelo.dart';
import 'agora_providers.dart';
import 'ligados_provider.dart';

/// «Agora»: tudo o que está à espera do Cesar, numa só fila, por urgência.
///
/// Cada cartão traz os botões do que se faz a seguir (Aceitar/Recusar,
/// Renovar/Negar, Ligar/Resolvido…). Quando um cartão é tratado sai do topo e
/// desce para «Tratados» (no fim da fila, até à meia-noite); o que se tratou fica
/// no Histórico.
class AgoraScreen extends ConsumerStatefulWidget {
  const AgoraScreen({super.key});

  @override
  ConsumerState<AgoraScreen> createState() => _AgoraScreenState();
}

/// Ordem dos chips de tipo: Acessos, A expirar, Expiradas, Ajuda, Sugestões (e
/// os dois tipos menos frequentes, depois dos Acessos).
const _ordemChips = <TipoAgora>[
  TipoAgora.acessoFist,
  TipoAgora.terminalNovo,
  TipoAgora.renovacao,
  TipoAgora.aExpirar,
  TipoAgora.expirada,
  TipoAgora.ajuda,
  TipoAgora.sugestao,
];

class _AgoraScreenState extends ConsumerState<AgoraScreen>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _pushSub;

  /// Itens com uma acção a decorrer — trava o duplo toque no mesmo cartão.
  final Set<String> _ocupados = {};

  bool _tratadosAbertos = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Push em primeiro plano → fila nova. O ecrã fica montado mesmo noutro
    // separador, por isso actualiza (e o badge com ele).
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
    } catch (e, st) {
      mostrarErro(e, stack: st);
    } finally {
      _ocupados.remove(i.chave);
      if (mounted) setState(() {});
    }
  }

  Future<bool> _confirmar(String titulo, String mensagem, String rotulo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.vermelho700,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text(rotulo),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // ── Corpo do cartão: abre o detalhe que já existe ─────────────────────────
  void _abrirDetalhe(ItemAgora i) => switch (i.tipo) {
    TipoAgora.expirada || TipoAgora.aExpirar || TipoAgora.renovacao => _abrir(
      DetalheClienteScreen(machineId: i.machineId!),
    ),
    // Um terminal novo ainda não tem licença: não há ficha, só a activação.
    TipoAgora.terminalNovo => _abrir(AtivarInstalacaoScreen(ping: i.ping!)),
    TipoAgora.ajuda => _abrir(DetalhePedidoAjudaScreen(pedido: i.pedidoAjuda!)),
    TipoAgora.acessoFist => _decidirFist(i),
    TipoAgora.sugestao => _abrir(DetalheSugestaoScreen(sugestao: i.sugestao!)),
  };

  // ── Acções ────────────────────────────────────────────────────────────────

  /// «Renovar» sem abrir a ficha: bottom sheet com o plano e as durações.
  Future<void> _renovar(ItemAgora i) async {
    final l = i.licenca ??
        await ref.read(licencasRepoProvider).porMachineId(i.machineId!);
    if (l == null) {
      mostrarMensagem('Não encontrei a licença deste cliente.');
      return;
    }
    if (!mounted) return;
    // Se o cliente também pediu renovação, fica confirmado com esta.
    final pedido = i.renovacao ??
        await ref.read(pedidosRepoProvider).pendentePorNif(l.nif, app: l.app);
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
  }

  /// Abre o ecrã «Decidir» (escolher a empresa, criar nova, limite).
  Future<void> _decidirFist(ItemAgora i) async {
    try {
      final empresas = await ref.read(punhoAdminRepoProvider).listarEmpresas();
      if (!mounted) return;
      await abrirDecisaoFist(context, ref, i.fistPedido!, empresas);
    } catch (e, st) {
      mostrarErro(e, stack: st);
    }
    _refrescar();
  }

  /// «Aceitar»: num toque quando veio por convite (a empresa já existe); se
  /// não, abre o passo de escolher/criar a empresa e o limite.
  Future<void> _aceitarFist(ItemAgora i) async {
    final p = i.fistPedido!;
    if (!p.porConvite) return _decidirFist(i);
    await aplicarDecisaoFist(ref, p, const DecisaoFist('aprovar'));
    _refrescar();
  }

  Future<void> _recusarFist(ItemAgora i) async {
    final p = i.fistPedido!;
    if (!await confirmarRecusar(context, p.nomeApresentavel)) return;
    await aplicarDecisaoFist(ref, p, const DecisaoFist('recusar'));
    _refrescar();
  }

  /// «Negar» numa licença sem pedido: o cliente passa para Clientes › Antigos.
  Future<void> _negarLicenca(ItemAgora i) async {
    final ok = await _confirmar(
      'Deixar de contar com ${i.titulo}?',
      'Sai da fila e passa para Clientes › Antigos. Podes reativar quando quiseres.',
      'Negar',
    );
    if (!ok) return;
    await ref.read(clientesAntigosRepoProvider).passarParaAntigo(
          machineId: i.machineId!,
          app: i.app,
          titulo: i.titulo,
        );
    await registarAccao(
      ref,
      tipo: i.tipo.etiqueta,
      titulo: i.titulo,
      app: i.app,
      machineId: i.machineId,
      pedido: i.subtitulo(),
      accao: 'Passou para Clientes › Antigos',
    );
    ref.invalidate(clientesAntigosProvider);
    _refrescar();
  }

  Future<void> _negarRenovacao(ItemAgora i) async {
    final ok = await _confirmar(
      'Negar a renovação de ${i.titulo}?',
      'O pedido de renovação fica recusado.',
      'Negar',
    );
    if (!ok) return;
    await ref.read(pedidosRepoProvider).recusar(i.renovacao!.id);
    await registarAccao(
      ref,
      tipo: 'Pedido de renovação',
      titulo: i.titulo,
      app: i.app,
      machineId: i.machineId,
      pedido: 'Pediu renovação (${i.renovacao!.planoDesejado})',
      accao: 'Pedido recusado',
    );
    _refrescar();
  }

  Future<void> _marcarLida(ItemAgora i) async {
    final s = i.sugestao!;
    await ref.read(sugestoesRepoProvider).marcarLida(s.id);
    await registarAccao(
      ref,
      tipo: 'Sugestão',
      titulo: i.titulo,
      app: i.app,
      machineId: i.machineId,
      pedido: i.detalhe,
      accao: 'Marcada como lida',
    );
    _refrescar();
  }

  /// «Ligar»: abre a app de chamadas com o número. O cartão desce logo para
  /// «Tratados»; falta ainda «Resolvido».
  Future<void> _ligar(ItemAgora i) async {
    await Acoes.ligarPara(i.telefone);
    await ref.read(ligadosProvider.notifier).marcar(i.chave);
    await registarAccao(
      ref,
      tipo: 'Pedido de ajuda',
      titulo: i.titulo,
      app: i.app,
      machineId: i.machineId,
      pedido: i.detalhe ?? 'Pediu ajuda',
      accao: 'Chamada aberta',
    );
  }

  Future<void> _resolver(ItemAgora i) async {
    await resolverPedidoAjuda(
      ref,
      i.pedidoAjuda!,
      quem: i.titulo,
      depois: () async {
        if (mounted) await _recarregar();
      },
    );
    await ref.read(ligadosProvider.notifier).desmarcar(i.chave);
  }

  /// Os botões de cada tipo de cartão.
  List<_Accao> _accoes(ItemAgora i) {
    final ocupado = _ocupados.contains(i.chave);
    VoidCallback? com(Future<void> Function() f) =>
        ocupado ? null : () => _comTrava(i, f);
    return switch (i.tipo) {
      TipoAgora.acessoFist => [
        _Accao(
          (i.fistPedido?.porConvite ?? false) ? 'Aceitar' : 'Aceitar e criar empresa',
          Icons.check,
          AppColors.verde700,
          com(() => _aceitarFist(i)),
        ),
        _Accao(
          'Recusar',
          Icons.close,
          AppColors.vermelho700,
          com(() => _recusarFist(i)),
          contorno: true,
        ),
      ],
      TipoAgora.expirada || TipoAgora.aExpirar => [
        _Accao('Renovar', Icons.event_available, i.tipo.corForte, com(() => _renovar(i))),
        _Accao(
          'Negar',
          Icons.block,
          AppColors.vermelho700,
          com(() => _negarLicenca(i)),
          contorno: true,
        ),
      ],
      TipoAgora.renovacao => [
        _Accao('Renovar', Icons.event_available, i.tipo.corForte, com(() => _renovar(i))),
        _Accao(
          'Negar',
          Icons.block,
          AppColors.vermelho700,
          com(() => _negarRenovacao(i)),
          contorno: true,
        ),
      ],
      TipoAgora.terminalNovo => [
        _Accao(
          'Activar',
          Icons.play_circle_outline,
          i.tipo.corForte,
          ocupado ? null : () => _abrir(AtivarInstalacaoScreen(ping: i.ping!)),
        ),
      ],
      TipoAgora.sugestao => [
        _Accao(
          'Abrir',
          Icons.menu_book_outlined,
          i.tipo.corForte,
          ocupado ? null : () => _abrir(DetalheSugestaoScreen(sugestao: i.sugestao!)),
        ),
        _Accao(
          'Marcar como lida',
          Icons.done,
          i.tipo.corForte,
          com(() => _marcarLida(i)),
          contorno: true,
        ),
      ],
      TipoAgora.ajuda => [
        _Accao(
          'Ligar',
          Icons.phone,
          AppColors.azul700,
          (i.telefone == null || ocupado) ? null : () => _ligar(i),
        ),
        _Accao('Resolvido', Icons.check, AppColors.verde700, com(() => _resolver(i))),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final filtro = ref.watch(appFilterProvider);
    final agora = ref.watch(agoraProvider);
    final escolhido = ref.watch(agoraTipoFiltroProvider);
    final ligados = ref.watch(ligadosProvider);
    final historico = ref.watch(historicoProvider).valueOrNull ?? const [];

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
        actions: const [EnvelopePedidosSite(), MenuControl()],
      ),
      body: Column(
        children: [
          const WiBarraApps(),
          Expanded(
            child: agora.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErroView(erro: e, onRetry: _recarregar),
              data: (data) {
                // O que já se ligou desce para «Tratados» (continua aberto).
                final fila = [
                  for (final i in data.itens)
                    if (!ligados.contains(i.chave)) i,
                ];
                final tratadosLigados = [
                  for (final i in data.itens)
                    if (ligados.contains(i.chave)) i,
                ];
                final contagem = contarPorTipo(fila);
                // Se o tipo escolhido esvaziou (tratou-se o último), volta a
                // mostrar tudo em vez de uma lista vazia que parece um erro.
                final tipo = (escolhido != null && (contagem[escolhido] ?? 0) > 0)
                    ? escolhido
                    : null;
                final visiveis = tipo == null
                    ? fila
                    : fila.where((i) => i.tipo == tipo).toList();
                final hoje = DateTime.now();
                final doDia = [
                  for (final r in historico)
                    if (r.criadoEm.year == hoje.year &&
                        r.criadoEm.month == hoje.month &&
                        r.criadoEm.day == hoje.day &&
                        r.accao != 'Chamada aberta' &&
                        (r.app == null || filtro.aceita(r.app!)))
                      r,
                ];
                final nTratados = tratadosLigados.length + doDia.length;
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(historicoProvider);
                    await _recarregar();
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: [
                      if (fila.isNotEmpty)
                        _Chips(
                          total: fila.length,
                          contagem: contagem,
                          escolhido: tipo,
                          onEscolher: (t) =>
                              ref.read(agoraTipoFiltroProvider.notifier).state = t,
                        ),
                      if (visiveis.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 48, bottom: 24),
                          child: WiEmptyState(
                            icone: Icons.check_circle_outline,
                            titulo: 'Nada pendente',
                            mensagem: 'Nenhum cliente está à tua espera.',
                          ),
                        ),
                      for (final i in visiveis) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _Cartao(
                          key: ValueKey(i.chave),
                          item: i,
                          accoes: _accoes(i),
                          onAbrir: () => _abrirDetalhe(i),
                        ),
                      ],
                      if (nTratados > 0) ...[
                        const SizedBox(height: AppSpacing.lg),
                        InkWell(
                          onTap: () => setState(
                            () => _tratadosAbertos = !_tratadosAbertos,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'TRATADOS HOJE ($nTratados)',
                                    style: AppText.label,
                                  ),
                                ),
                                Icon(
                                  _tratadosAbertos
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_tratadosAbertos) ...[
                          for (final i in tratadosLigados) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Opacity(
                              opacity: 0.65,
                              child: _Cartao(
                                key: ValueKey('ligado:${i.chave}'),
                                item: i,
                                nota: 'Chamada aberta. Falta marcar como resolvido.',
                                accoes: [
                                  _Accao(
                                    'Resolvido',
                                    Icons.check,
                                    AppColors.verde700,
                                    _ocupados.contains(i.chave)
                                        ? null
                                        : () => _comTrava(i, () => _resolver(i)),
                                  ),
                                  _Accao(
                                    'Voltar à fila',
                                    Icons.undo,
                                    AppColors.azul700,
                                    () => ref
                                        .read(ligadosProvider.notifier)
                                        .desmarcar(i.chave),
                                    contorno: true,
                                  ),
                                ],
                                onAbrir: () => _abrirDetalhe(i),
                              ),
                            ),
                          ],
                          for (final r in doDia) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _LinhaTratada(registo: r),
                          ],
                        ],
                      ],
                    ],
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

String _nomeDoFiltro(AppFiltro f) => switch (f) {
  AppFiltro.todas => 'Todas',
  _ => f.etiqueta,
};

/// Um botão de um cartão.
class _Accao {
  final String rotulo;
  final IconData icone;
  final Color cor;
  final VoidCallback? onTap;

  /// Botão de contorno (acção secundária ou de recusa) em vez de preenchido.
  final bool contorno;

  const _Accao(this.rotulo, this.icone, this.cor, this.onTap, {this.contorno = false});
}

/// Chips de contagem por tipo; tocar filtra a fila, tocar outra vez limpa. As
/// linhas quebram em vez de deslizar de lado, para se verem todos.
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
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        WiChipFiltro(
          label: 'Tudo ($total)',
          activo: escolhido == null,
          onTap: () => onEscolher(null),
        ),
        for (final t in _ordemChips)
          if ((contagem[t] ?? 0) > 0)
            WiChipFiltro(
              label: '${t.chip} (${contagem[t]})',
              activo: escolhido == t,
              onTap: () => onEscolher(escolhido == t ? null : t),
            ),
      ],
    );
  }
}

class _Cartao extends StatelessWidget {
  final ItemAgora item;
  final List<_Accao> accoes;
  final VoidCallback onAbrir;

  /// Linha extra por baixo (por ex. «Chamada aberta…» nos tratados).
  final String? nota;

  const _Cartao({
    super.key,
    required this.item,
    required this.accoes,
    required this.onAbrir,
    this.nota,
  });

  ButtonStyle _estilo(Color cor) => FilledButton.styleFrom(
    backgroundColor: cor,
    // Alvo de toque ≥ 48 dp.
    minimumSize: const Size(0, 48),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
  );

  @override
  Widget build(BuildContext context) {
    final t = item.tipo;
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
          if (t == TipoAgora.ajuda && item.telefone == null)
            const Text('Sem telefone registado.', style: AppText.caption),
          if (nota != null) Text(nota!, style: AppText.caption),
          const SizedBox(height: AppSpacing.md),
          // Acções na metade de baixo do cartão: é onde o polegar chega.
          Row(
            children: [
              for (var n = 0; n < accoes.length; n++) ...[
                if (n > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: _botao(accoes[n])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _botao(_Accao a) => a.contorno
      ? OutlinedButton.icon(
          onPressed: a.onTap,
          icon: Icon(a.icone, size: 18),
          style: OutlinedButton.styleFrom(
            foregroundColor: a.cor,
            side: BorderSide(color: a.cor),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          ),
          label: Text(a.rotulo, textAlign: TextAlign.center),
        )
      : FilledButton.icon(
          onPressed: a.onTap,
          icon: Icon(a.icone, size: 18),
          style: _estilo(a.cor),
          label: Text(a.rotulo, textAlign: TextAlign.center),
        );
}

/// Uma linha de «Tratados hoje»: o que se fez, esbatido, sem botões.
class _LinhaTratada extends StatelessWidget {
  const _LinhaTratada({required this.registo});

  final RegistoHistorico registo;

  @override
  Widget build(BuildContext context) {
    final h = registo.criadoEm;
    final hora =
        '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
    return Opacity(
      opacity: 0.65,
      child: WiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(registo.tipo, style: AppText.label)),
                Text(hora, style: AppText.caption),
              ],
            ),
            Text(registo.titulo, style: AppText.bodyStrong),
            Text(registo.accao, style: AppText.caption),
          ],
        ),
      ),
    );
  }
}
