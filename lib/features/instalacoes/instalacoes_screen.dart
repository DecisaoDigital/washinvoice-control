import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../../core/exibicao.dart';
import '../../core/localidades.dart';
import '../../core/versoes.dart';
import '../../core/widgets/widgets.dart';
import '../../models/licenca.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';
import '../../repositories/punho_admin_repository.dart';
import '../mapa/mapa_screen.dart';
import '../nav/menu_control.dart';
import '../../repositories/clientes_antigos_repository.dart';
import 'detalhe_cliente_screen.dart';

class _InstalacoesData {
  final List<Licenca> licencas;
  final Map<String, Ping> pingPorMachine;
  final ContextoInstalacoes ctx;
  final List<ClienteAntigo> antigos;
  _InstalacoesData(this.licencas, this.pingPorMachine, this.ctx, this.antigos);
}

enum OrdenacaoInstalacoes { ultimoAcesso, nome, validade, localidade }

extension OrdenacaoLabel on OrdenacaoInstalacoes {
  String get label {
    switch (this) {
      case OrdenacaoInstalacoes.ultimoAcesso:
        return 'Último acesso';
      case OrdenacaoInstalacoes.nome:
        return 'Nome do cliente';
      case OrdenacaoInstalacoes.validade:
        return 'Validade';
      case OrdenacaoInstalacoes.localidade:
        return 'Localidade';
    }
  }
}

const _kPrefOrdenacao = 'instalacoes_ordenacao';

/// Ordena as licenças por [ordenacao] (função pura, testável). Usa o [ctx] para
/// nome/localidade e [pingPorMachine] para o último acesso.
List<Licenca> ordenarInstalacoes(
  List<Licenca> lista,
  OrdenacaoInstalacoes ordenacao, {
  required ContextoInstalacoes ctx,
  required Map<String, Ping> pingPorMachine,
}) {
  final l = [...lista];
  switch (ordenacao) {
    case OrdenacaoInstalacoes.ultimoAcesso:
      l.sort((a, b) {
        final pa = pingPorMachine[a.machineId]?.criadoEm;
        final pb = pingPorMachine[b.machineId]?.criadoEm;
        if (pa == null && pb == null) return 0;
        if (pa == null) return 1; // sem ping vai para o fim
        if (pb == null) return -1;
        return pb.compareTo(pa); // mais recente primeiro
      });
    case OrdenacaoInstalacoes.nome:
      l.sort(
        (a, b) => ctx
            .nomeDe(machineId: a.machineId, nif: a.nif)
            .toLowerCase()
            .compareTo(
              ctx.nomeDe(machineId: b.machineId, nif: b.nif).toLowerCase(),
            ),
      );
    case OrdenacaoInstalacoes.validade:
      l.sort((a, b) => a.validade.compareTo(b.validade)); // fim mais próximo
    case OrdenacaoInstalacoes.localidade:
      String loc(Licenca x) {
        final c = ctx.clienteDe(machineId: x.machineId, nif: x.nif);
        if (c?.localidade != null && c!.localidade!.trim().isNotEmpty) {
          return c.localidade!.trim().toLowerCase();
        }
        return Localidades.traduzir(
          pingPorMachine[x.machineId]?.cidade,
        ).toLowerCase();
      }

      l.sort((a, b) => loc(a).compareTo(loc(b)));
  }
  return l;
}

class InstalacoesScreen extends ConsumerStatefulWidget {
  const InstalacoesScreen({super.key});

  @override
  ConsumerState<InstalacoesScreen> createState() => _InstalacoesScreenState();
}

class _InstalacoesScreenState extends ConsumerState<InstalacoesScreen> {
  late Future<_InstalacoesData> _future;

  // Filtros aplicados client-side (R1). Por defeito mostra só Activas.
  String _filtro = '';
  bool _soActivas = true;
  bool _verAntigos = false;
  String? _versao;
  String? _cidade;
  int? _semPingDias;
  OrdenacaoInstalacoes _ordenacao = OrdenacaoInstalacoes.ultimoAcesso;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
    // Recupera a ordenação preferida (persistida entre sessões).
    SharedPreferences.getInstance().then((prefs) {
      final nome = prefs.getString(_kPrefOrdenacao);
      if (nome == null || !mounted) return;
      final match = OrdenacaoInstalacoes.values.where((e) => e.name == nome);
      if (match.isNotEmpty) setState(() => _ordenacao = match.first);
    });
  }

  void _mudarOrdenacao(OrdenacaoInstalacoes o) {
    setState(() => _ordenacao = o);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_kPrefOrdenacao, o.name),
    );
  }

  List<Licenca> _ordenar(List<Licenca> lista, _InstalacoesData data) =>
      ordenarInstalacoes(
        lista,
        _ordenacao,
        ctx: data.ctx,
        pingPorMachine: data.pingPorMachine,
      );

  Future<_InstalacoesData> _carregar() async {
    final licencasRepo = ref.read(licencasRepoProvider);
    final pingsRepo = ref.read(pingsRepoProvider);
    final clientesRepo = ref.read(clientesRepoProvider);

    // `read` e não `watch`: quem dispara o recarregamento é o `ref.listen` do
    // build (mesmo padrão do Dashboard).
    final app = ref.read(appFilterProvider).valorApp;

    // Os nomes que o Fist já sabe. Falham em silêncio: uma instalação sem
    // nome do Fist continua a resolver-se como sempre, e o ecrã não deixa de
    // abrir por causa disto.
    final nomesFistF = ref
        .read(punhoAdminRepoProvider)
        .nomesPorTerminal()
        .catchError((_) => <String, NomeDoTerminalFist>{});

    final licencasF = licencasRepo.listar(app: app);
    final pingsF = pingsRepo.ultimosPorInstalacao(app: app);
    final clientesF = clientesRepo.listar();
    final antigosF = ref
        .read(clientesAntigosRepoProvider)
        .listar()
        .catchError((_) => <ClienteAntigo>[]);
    await Future.wait([licencasF, pingsF, clientesF, nomesFistF, antigosF]);

    final licencas = await licencasF;
    final pings = await pingsF;
    final clientes = await clientesF;
    final mapa = {for (final p in pings) p.machineId: p};
    return _InstalacoesData(
      licencas,
      mapa,
      ContextoInstalacoes.build(
        clientes: clientes,
        licencas: licencas,
        pings: pings,
        nomesFist: await nomesFistF,
      ),
      await antigosF,
    );
  }

  Future<void> _recarregar() async {
    setState(() {
      _future = _carregar();
    });
    await _future;
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

  /// Atalhos da vista lista: prolongar 5 dias e suspender/reactivar sem entrar
  /// no detalhe. As acções destrutivas com consequência maior (cancelar, mudar
  /// de plano) ficam só no detalhe — não se põem a um toque de distância numa
  /// lista onde se percorre depressa.
  Future<void> _accoesRapidas(Licenca l) async {
    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.more_time, color: AppColors.azul700),
              title: Text(l.diasContamDeHoje ? '5 dias' : '+5 dias'),
              onTap: () => Navigator.pop(ctx, 'dias'),
            ),
            if (l.activa)
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.vermelho),
                title: const Text('Suspender'),
                onTap: () => Navigator.pop(ctx, 'suspender'),
              )
            else
              ListTile(
                leading: const Icon(Icons.check_circle, color: AppColors.verde),
                title: const Text('Reactivar'),
                onTap: () => Navigator.pop(ctx, 'reactivar'),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Ver detalhes'),
              onTap: () => Navigator.pop(ctx, 'detalhe'),
            ),
          ],
        ),
      ),
    );
    if (escolha == null || !mounted) return;

    if (escolha == 'detalhe') {
      _abrirDetalhe(l.machineId);
      return;
    }

    // Suspender daqui pede confirmação: na lista é fácil tocar na linha errada.
    if (escolha == 'suspender') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Suspender licença?'),
          content: Text(
            'O terminal de ${l.nome ?? l.nif} fica bloqueado dentro de '
            '5 minutos. Podes reactivar a qualquer momento.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.vermelho,
              ),
              child: const Text('Suspender'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final servico = ref.read(gerirLicencaProvider);
    try {
      final mensagem = switch (escolha) {
        'dias' =>
          await servico
              .darDias(l, 5)
              .then(
                (r) => l.diasContamDeHoje
                    ? '5 dias a contar de hoje — validade ${Dates.data(r.validade)}.'
                    : 'Prolongada 5 dias — validade ${Dates.data(r.validade)}.',
              ),
        'suspender' =>
          await servico
              .suspender(l.machineId)
              .then((_) => 'Licença suspensa. O POS tranca em ≤5 min.'),
        'reactivar' =>
          await servico
              .reactivar(l.machineId)
              .then((_) => 'Licença reactivada. O POS destranca em ≤5 min.'),
        _ => null,
      };
      if (!mounted || mensagem == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));
      await _recarregar();
    } catch (e, st) {
      mostrarErro(e, stack: st);
    }
  }

  List<Licenca> _filtrar(_InstalacoesData data) {
    final q = _filtro.trim().toLowerCase();
    final agora = DateTime.now();
    final idsAntigos = {for (final a in data.antigos) a.machineId};
    return data.licencas.where((l) {
      if (idsAntigos.contains(l.machineId)) return false;
      if (q.isNotEmpty) {
        final bate =
            (l.nome?.toLowerCase().contains(q) ?? false) ||
            l.nif.toLowerCase().contains(q) ||
            l.machineId.toLowerCase().contains(q);
        if (!bate) return false;
      }
      if (_soActivas && l.estado != EstadoLicenca.activa) return false;

      final ping = data.pingPorMachine[l.machineId];
      if (_versao != null && ping?.versao != _versao) return false;
      if (_cidade != null && ping?.cidade != _cidade) return false;
      if (_semPingDias != null) {
        final semPing =
            ping == null ||
            agora.difference(ping.criadoEm).inDays >= _semPingDias!;
        if (!semPing) return false;
      }
      return true;
    }).toList();
  }

  Widget _barraFiltros(List<String> versoes, List<String> cidades) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          PopupMenuButton<OrdenacaoInstalacoes>(
            onSelected: _mudarOrdenacao,
            position: PopupMenuPosition.under,
            itemBuilder: (_) => OrdenacaoInstalacoes.values
                .map((o) => PopupMenuItem(value: o, child: Text(o.label)))
                .toList(),
            child: WiChipFiltro(
              label: 'Ordenar: ${_ordenacao.label}',
              activo: true,
              comSeta: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          WiChipFiltro(
            label: 'Activas',
            activo: _soActivas,
            onTap: () => setState(() => _soActivas = !_soActivas),
          ),
          const SizedBox(width: AppSpacing.sm),
          _ChipMenu<String>(
            labelBase: 'Todas versões',
            valor: _versao,
            opcoes: versoes,
            labelOpcao: (v) => 'v$v',
            onChanged: (v) => setState(() => _versao = v),
          ),
          const SizedBox(width: AppSpacing.sm),
          _ChipMenu<String>(
            labelBase: 'Todas localidades',
            valor: _cidade,
            opcoes: cidades,
            // Valor filtra pelo cidade cru da base; a etiqueta mostra-se em PT.
            labelOpcao: (v) => Localidades.traduzir(v),
            onChanged: (v) => setState(() => _cidade = v),
          ),
          const SizedBox(width: AppSpacing.sm),
          _ChipMenu<int>(
            labelBase: 'Sem ping há…',
            valor: _semPingDias,
            opcoes: const [3, 7, 14],
            labelOpcao: (n) => '$n+ dias',
            onChanged: (v) => setState(() => _semPingDias = v),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mudar de app no Dashboard tem de reflectir-se aqui — o filtro é global e
    // este ecrã fica montado no IndexedStack mesmo quando não está visível.
    ref.listen(appFilterProvider, (_, __) => _recarregar());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Mapa',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MapaScreen())),
          ),
          IconButton(
            iconSize: 20,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: _recarregar,
          ),
          const MenuControl(),
        ],
      ),
      body: Column(
        children: [
          const WiBarraApps(),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    0,
                  ),
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Clientes')),
                      ButtonSegment(value: true, label: Text('Antigos')),
                    ],
                    selected: {_verAntigos},
                    onSelectionChanged: (v) =>
                        setState(() => _verAntigos = v.first),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SearchBar(
                    hintText: 'Procurar por nome, NIF ou machine ID',
                    leading: const Icon(
                      Icons.search,
                      color: AppColors.textTertiary,
                    ),
                    backgroundColor: const WidgetStatePropertyAll(
                      AppColors.surface,
                    ),
                    elevation: const WidgetStatePropertyAll(1),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                    ),
                    onChanged: (v) => setState(() => _filtro = v),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<_InstalacoesData>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return ErroView(
                          erro: snapshot.error!,
                          onRetry: _recarregar,
                        );
                      }
                      final data = snapshot.data!;
                      if (_verAntigos) return _listaAntigos(data);
                      final classV = ClassificadorVersoes(
                        data.pingPorMachine.values.map((p) => p.versao),
                      );
                      final versoes =
                          data.pingPorMachine.values
                              .map((p) => p.versao)
                              .whereType<String>()
                              .toSet()
                              .toList()
                            ..sort();
                      final cidades =
                          data.pingPorMachine.values
                              .map((p) => p.cidade)
                              .whereType<String>()
                              .toSet()
                              .toList()
                            ..sort();
                      final licencas = _ordenar(_filtrar(data), data);
                      return Column(
                        children: [
                          _resumo(data),
                          _barraFiltros(versoes, cidades),
                          const SizedBox(height: AppSpacing.sm),
                          Expanded(
                            child: licencas.isEmpty
                                ? const WiEmptyState(
                                    icone: Icons.search_off,
                                    titulo: 'Sem resultados',
                                    mensagem:
                                        'Nenhuma instalação corresponde aos filtros.',
                                  )
                                : RefreshIndicator(
                                    onRefresh: _recarregar,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                        AppSpacing.lg,
                                        0,
                                        AppSpacing.lg,
                                        AppSpacing.lg,
                                      ),
                                      itemCount: licencas.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: AppSpacing.sm),
                                      itemBuilder: (context, i) {
                                        final l = licencas[i];
                                        final ping =
                                            data.pingPorMachine[l.machineId];
                                        return _CartaoInstalacao(
                                          licenca: l,
                                          ping: ping,
                                          ctx: data.ctx,
                                          estadoVersao: classV.estadoDe(
                                            ping?.versao,
                                          ),
                                          onTap: () =>
                                              _abrirDetalhe(l.machineId),
                                          onAccoesRapidas: () =>
                                              _accoesRapidas(l),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Os números do antigo Resumo, no topo de Clientes.
  Widget _resumo(_InstalacoesData data) {
    final ids = {for (final a in data.antigos) a.machineId};
    final ls = data.licencas.where((l) => !ids.contains(l.machineId));
    int n(EstadoLicenca e) => ls.where((l) => l.estado == e).length;
    Widget kpi(String rot, int v, Color cor) => Expanded(
      child: Column(
        children: [
          Text(
            '$v',
            style: AppText.bodyStrong.copyWith(color: cor, fontSize: 20),
          ),
          Text(rot, style: AppText.caption),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          kpi('Activas', n(EstadoLicenca.activa), AppColors.verde700),
          kpi('A expirar', n(EstadoLicenca.aExpirar), AppColors.laranja700),
          kpi('Expiradas', n(EstadoLicenca.expirada), AppColors.vermelho700),
          kpi('Suspensas', n(EstadoLicenca.suspensa), AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _listaAntigos(_InstalacoesData data) {
    final app = ref.read(appFilterProvider);
    final q = _filtro.trim().toLowerCase();
    final lista = [
      for (final a in data.antigos)
        if ((a.app == null || app.aceita(a.app!)) &&
            (q.isEmpty || (a.titulo ?? a.machineId).toLowerCase().contains(q)))
          a,
    ];
    if (lista.isEmpty) {
      return const WiEmptyState(
        icone: Icons.inventory_2_outlined,
        titulo: 'Sem clientes antigos',
        mensagem: 'Os clientes a quem disseres «Negar» aparecem aqui.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final a in lista) ...[
          WiCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.titulo ?? a.machineId, style: AppText.bodyStrong),
                      Text(
                        'Antigo desde ${Dates.data(a.desde)}',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(clientesAntigosRepoProvider)
                          .reactivar(a.machineId);
                      ref.invalidate(clientesAntigosProvider);
                      await _recarregar();
                    } catch (e, st) {
                      mostrarErro(e, stack: st);
                    }
                  },
                  child: const Text('Reativar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Chip de filtro que abre um menu de opções (versão/localidade/sem-ping).
class _ChipMenu<T> extends StatelessWidget {
  final String labelBase;
  final T? valor;
  final List<T> opcoes;
  final String Function(T) labelOpcao;
  final ValueChanged<T?> onChanged;

  const _ChipMenu({
    required this.labelBase,
    required this.valor,
    required this.opcoes,
    required this.labelOpcao,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T?>(
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem<T?>(value: null, child: Text(labelBase)),
        ...opcoes.map(
          (o) => PopupMenuItem<T?>(value: o, child: Text(labelOpcao(o))),
        ),
      ],
      position: PopupMenuPosition.under,
      child: WiChipFiltro(
        label: valor == null ? labelBase : labelOpcao(valor as T),
        activo: valor != null,
        comSeta: true,
      ),
    );
  }
}

class _CartaoInstalacao extends StatelessWidget {
  final Licenca licenca;
  final Ping? ping;
  final ContextoInstalacoes ctx;
  final EstadoVersao estadoVersao;
  final VoidCallback onTap;
  final VoidCallback onAccoesRapidas;

  const _CartaoInstalacao({
    required this.licenca,
    required this.ping,
    required this.ctx,
    required this.estadoVersao,
    required this.onTap,
    required this.onAccoesRapidas,
  });

  String _validadeTexto() {
    final estado = licenca.estado;
    if (estado == EstadoLicenca.expirada) {
      return 'expirada ${timeago.format(licenca.validade, locale: 'pt')}';
    }
    if (estado == EstadoLicenca.aExpirar) {
      return 'expira ${timeago.format(licenca.validade, locale: 'pt', allowFromNow: true)}';
    }
    return 'expira ${Dates.data(licenca.validade)}';
  }

  @override
  Widget build(BuildContext context) {
    final expirada = licenca.estado == EstadoLicenca.expirada;
    final card = WiCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 32,
            decoration: BoxDecoration(
              color: licenca.estado.cor,
              borderRadius: AppRadius.smAll,
            ),
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
                          machineId: licenca.machineId,
                          nif: licenca.nif,
                        ),
                        style: AppText.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${licenca.planoLabel} · ${_validadeTexto()}',
                  style: AppText.label.copyWith(color: AppColors.textSecondary),
                ),
                Row(
                  children: [
                    Icon(
                      Exibicao.iconeSinal(ping?.metodoGeo),
                      size: 13,
                      color: Exibicao.corSinal(ping?.metodoGeo),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${ctx.sinalLocalidadeDe(machineId: licenca.machineId, nif: licenca.nif)}'
                        '${ping != null ? ' · ${timeago.format(ping!.criadoEm, locale: 'pt')}' : ''}',
                        style: AppText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (ping != null) ...[
            VersaoBadge(versao: ping!.versao, estado: estadoVersao),
            const SizedBox(width: 4),
          ],
          // Atalhos rápidos sem entrar no detalhe — para a gestão do dia-a-dia
          // (um cliente liga a pedir mais uns dias e resolve-se aqui mesmo).
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.textTertiary),
            tooltip: 'Acções rápidas',
            onPressed: onAccoesRapidas,
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
    return expirada ? Opacity(opacity: 0.75, child: card) : card;
  }
}
