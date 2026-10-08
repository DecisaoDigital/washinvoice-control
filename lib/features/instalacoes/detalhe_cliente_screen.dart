import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/acoes.dart';
import '../../core/contexto_instalacoes.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../core/exibicao.dart';
import '../../core/localidades.dart';
import '../../core/versoes.dart';
import '../../core/quem_titulo.dart';
import '../../core/widgets/widgets.dart';
import '../../models/aceite_termo.dart';
import '../../models/cliente.dart';
import '../../models/licenca.dart';
import '../../models/pedido_renovacao.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';
import '../../services/licenca/gerir_licenca_service.dart';
import '../../services/licenca_emissao.dart';
import 'card_series_widget.dart';
import 'confirmar_apagar_licenca.dart';
import 'renovar_licenca.dart';
import 'controlo_remoto_widgets.dart';

class _DetalheData {
  final Licenca licenca;
  final Ping? ultimoPing;
  final PedidoRenovacao? pedidoPendente;
  final AceiteTermo? aceiteTermos;
  final EstadoVersao estadoVersao;
  final String? versaoAtual;
  final Cliente? cliente;
  final int ordem;
  final int total;

  /// Nome que a cascata única (`ContextoInstalacoes.nomeDe`) dá a este
  /// terminal — o que se mostra quando não há nome comercial nem designação.
  final String nomeDaCascata;
  _DetalheData(
    this.licenca,
    this.ultimoPing,
    this.pedidoPendente,
    this.aceiteTermos,
    this.estadoVersao,
    this.versaoAtual,
    this.cliente,
    this.ordem,
    this.total,
    this.nomeDaCascata,
  );

  /// Designação social (nome legal). O cliente sincronizado manda; a licença é
  /// o recurso quando ainda não há linha em `clientes`.
  String get designacaoSocial {
    final doCliente = cliente?.nome.trim() ?? '';
    if (doCliente.isNotEmpty) return doCliente;
    return licenca.nome?.trim() ?? '';
  }

  /// Nome comercial — como a loja é conhecida.
  String get nomeComercial {
    final doCliente = cliente?.nomeComercial?.trim() ?? '';
    if (doCliente.isNotEmpty) return doCliente;
    return licenca.nomeComercial?.trim() ?? '';
  }

  /// O que vai em destaque no cabeçalho: o nome comercial, porque é por ele
  /// que se reconhece a loja. Sem ele, a designação social. Sem nenhum (POS
  /// ainda não sincronizou), o NIF, que pelo menos identifica.
  /// `true` quando o POS ainda não sincronizou a ficha da empresa — instalação
  /// nova, sem nome nem NIF real.
  bool get porConfigurar =>
      nomeComercial.isEmpty && designacaoSocial.isEmpty;

  String get nomeCliente {
    if (nomeComercial.isNotEmpty) return nomeComercial;
    if (designacaoSocial.isNotEmpty) return designacaoSocial;
    // Instalação nova: a cascata única decide (empresa que o Fist conhece →
    // nome da máquina → NIF real → «Fist · terminal xxxxxx»).
    return nomeDaCascata;
  }

  /// Região que o ping reporta (cidade do GPS ou do fornecedor de internet).
  /// Vazio quando não há sinal utilizável.
  String get regiaoDoPing {
    final p = ultimoPing;
    if (p == null || p.metodoGeo == null || p.metodoGeo == 'nenhum') return '';
    return Localidades.traduzir(p.cidade);
  }

  /// Linha pequena do cabeçalho: designação social (só quando o destaque é o
  /// nome comercial — senão repetia-se) e a posição do terminal.
  String get subtituloTerminal {
    final terminal = total > 1 ? 'Terminal $ordem de $total' : 'Terminal único';

    // Instalação nova: o título é o nome da máquina, por isso o que falta saber
    // é *onde* ela está. A região do ping é a única pista disponível antes de o
    // cliente configurar a ficha.
    if (porConfigurar) {
      final regiao = regiaoDoPing;
      return regiao.isEmpty
          ? 'Instalação nova · $terminal'
          : 'Instalação nova · $regiao';
    }

    final mostrarDesignacao =
        nomeComercial.isNotEmpty && designacaoSocial.isNotEmpty;
    return mostrarDesignacao ? '$designacaoSocial · $terminal' : terminal;
  }
}

class DetalheClienteScreen extends ConsumerStatefulWidget {
  final String machineId;
  const DetalheClienteScreen({super.key, required this.machineId});

  @override
  ConsumerState<DetalheClienteScreen> createState() =>
      _DetalheClienteScreenState();
}

class _DetalheClienteScreenState extends ConsumerState<DetalheClienteScreen> {
  late Future<_DetalheData> _future;

  /// Nome do cliente já resolvido (cascata do [_DetalheData.nomeCliente]),
  /// guardado para os títulos das confirmações.
  String? _nomeCliente;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<_DetalheData> _carregar() async {
    final licencasRepo = ref.read(licencasRepoProvider);
    final pedidosRepo = ref.read(pedidosRepoProvider);
    final pingsRepo = ref.read(pingsRepoProvider);
    final aceitesRepo = ref.read(aceitesRepoProvider);
    final clientesRepo = ref.read(clientesRepoProvider);

    final licenca = await licencasRepo.porMachineId(widget.machineId);
    if (licenca == null) {
      throw Exception(
          'Licença não encontrada para a máquina ${widget.machineId}.');
    }
    final historico = await pingsRepo.historico(licenca.machineId, limite: 1);
    // O pedido pendente é o da app desta licença — o mesmo NIF pode ter
    // pedidos noutra app, e sem o filtro o `maybeSingle()` rebentava.
    final pedido =
        await pedidosRepo.pendentePorNif(licenca.nif, app: licenca.app);
    final aceite = await aceitesRepo.ultimoPorMachineId(licenca.machineId);

    // Contexto restrito à app desta licença — não ao filtro global. O
    // "Terminal 2 de 3" conta os terminais do mesmo NIF, e um cliente que
    // tenha POS *e* Fist não deve ver os dois somados na mesma contagem.
    final todosUltimos = await pingsRepo.ultimosPorInstalacao(app: licenca.app);
    final todasLicencas = await licencasRepo.listar(app: licenca.app);
    final clientes = await clientesRepo.listar();
    final classV = ClassificadorVersoes(todosUltimos.map((p) => p.versao));
    final ultimoPing = historico.isNotEmpty ? historico.first : null;

    final nomesFist = await ContextoInstalacoes.carregarNomesFist(
      ref.read(punhoAdminRepoProvider),
    );
    final ctx = ContextoInstalacoes.build(
        clientes: clientes,
        licencas: todasLicencas,
        pings: todosUltimos,
        nomesFist: nomesFist);
    final ordemTotal = ctx.ordemDe(licenca.machineId);
    final cliente = ctx.clienteDe(
        clienteId: licenca.clienteId,
        machineId: licenca.machineId,
        nif: licenca.nif);

    final dados = _DetalheData(
      licenca,
      ultimoPing,
      pedido,
      aceite,
      classV.estadoDe(ultimoPing?.versao),
      classV.versaoAtual,
      cliente,
      ordemTotal?.$1 ?? 1,
      ordemTotal?.$2 ?? 1,
      ctx.nomeDe(
        machineId: licenca.machineId,
        nif: licenca.nif,
        comTerminal: false,
      ),
    );
    _nomeCliente = dados.nomeCliente;
    return dados;
  }

  void _recarregar() {
    setState(() { _future = _carregar(); });
  }

  /// Pergunta ao servidor o que está pendurado, mostra-o, e só depois apaga.
  ///
  /// A ordem importa: sem os números à frente, "Apagar?" é a mesma pergunta
  /// para uma linha solta do Fist e para uma licença do POS com cadeia
  /// fiscal, que não são de todo a mesma coisa.
  Future<void> _apagarLicenca(String id, {String? quem}) async {
    try {
      final repo = ref.read(licencasRepoProvider);
      final dependentes = await repo.dependentes(id);
      if (!mounted) return;

      final confirmado = await confirmarApagarLicenca(
        context,
        dependentes: dependentes,
        quem: quem,
      );
      if (!confirmado || !mounted) return;

      await repo.apagar(id);
      if (!mounted) return;
      messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Licença apagada.')),
      );
      // A licença que este ecrã mostra deixou de existir: ficar aqui era ficar
      // a olhar para dados que já não estão em lado nenhum.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) mostrarErro(e);
    }
  }

  /// «Renovar»: a mesma bottom sheet da fila «Agora» (+30 dias, +3 meses,
  /// +1 ano, Outra data), com «Anular».
  Future<void> _marcarRenovacao(Licenca l, PedidoRenovacao? pedido) =>
      renovarLicencaComSheet(
        context,
        ref,
        l,
        pedido: pedido,
        quem: _quem(l),
        depois: () async {
          if (mounted) _recarregar();
        },
      );

  // ── Controlo remoto ────────────────────────────────────────────────────────
  // Todas as acções passam pela Edge Function `gerir-licenca`: é ela que corre
  // com service_role (para o dia em que a RLS fechar) e que regista em
  // `licencas_audit` QUEM fez a acção — o trigger sozinho não consegue, porque
  // escritas com service_role não têm `auth.uid()`.

  /// `true` enquanto uma acção remota está a decorrer (trava os botões todos,
  /// para não se carregar em "+5 dias" três vezes seguidas).
  bool _aExecutar = false;

  /// Executa [accao] com confirmação, indicador de progresso e refresh.
  ///
  /// [confirmacao] a `null` salta o diálogo (usado para as acções aditivas
  /// como prolongar, que não têm consequência destrutiva).
  Future<void> _accaoRemota({
    required String machineId,
    required Future<LicencaAtualizada> Function(GerirLicencaService s) accao,
    required String Function(LicencaAtualizada r) sucesso,
    ({String titulo, String corpo, String confirmar, bool destrutiva})?
    confirmacao,

    /// Acção que desfaz esta (só nas reversíveis). Quando existe, o SnackBar
    /// de sucesso dura 8 s e traz «Anular».
    Future<LicencaAtualizada> Function(GerirLicencaService s)? anular,
    String Function(LicencaAtualizada r)? sucessoAnular,
  }) async {
    if (_aExecutar) return;

    if (confirmacao != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(confirmacao.titulo),
          content: Text(confirmacao.corpo),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: confirmacao.destrutiva
                  ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700)
                  : null,
              child: Text(confirmacao.confirmar),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _aExecutar = true);
    try {
      final resultado = await accao(ref.read(gerirLicencaProvider));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(sucesso(resultado)),
            duration: anular == null
                ? const Duration(seconds: 4)
                : const Duration(seconds: 8),
            persist: false, // com acção, o SnackBar não fecha sozinho se não o disserem
            action: anular == null
                ? null
                : SnackBarAction(
                    label: 'Anular',
                    onPressed: () => _anularRemota(
                      anular,
                      sucessoAnular ?? (_) => 'Acção anulada.',
                    ),
                  ),
          ),
        );
      _recarregar();
    } catch (e, st) {
      mostrarErro(e, stack: st);
    } finally {
      if (mounted) setState(() => _aExecutar = false);
    }
  }

  /// Desfaz uma acção reversível (o «Anular» do SnackBar). Sem diálogo: o
  /// próprio toque é a intenção. Usa a mesma Edge Function, por isso fica
  /// auditado como qualquer outra acção.
  Future<void> _anularRemota(
    Future<LicencaAtualizada> Function(GerirLicencaService s) accao,
    String Function(LicencaAtualizada r) sucesso,
  ) async {
    if (_aExecutar) return;
    setState(() => _aExecutar = true);
    try {
      final r = await accao(ref.read(gerirLicencaProvider));
      mostrarMensagem(sucesso(r));
      if (mounted) _recarregar();
    } catch (e, st) {
      mostrarErro(e, stack: st);
    } finally {
      if (mounted) setState(() => _aExecutar = false);
    }
  }

  /// Título das confirmações: cliente e série do terminal.
  String _quem(Licenca l) =>
      quemTitulo(_nomeCliente ?? 'este cliente',
          serie: l.serie, machineId: l.machineId);

  Future<void> _darDias(Licenca l, int dias) => _accaoRemota(
        machineId: l.machineId,
        accao: (s) => s.darDias(l, dias),
        // A frase diz o que aconteceu, não o que o botão se chama: num trial
        // a validade pode ter **encurtado**, e dizer "prolongada" seria mentir.
        sucesso: (r) => l.diasContamDeHoje
            ? '$dias dias a contar de hoje — validade ${Dates.data(r.validade)}. '
                'O terminal actualiza em ≤5 min.'
            : 'Prolongada $dias dias — validade ${Dates.data(r.validade)}. '
                'O POS actualiza em ≤5 min.',
      );

  Future<void> _suspender(Licenca l) => _accaoRemota(
    machineId: l.machineId,
    accao: (s) => s.suspender(l.machineId),
    sucesso: (_) => 'Licença suspensa. O POS tranca em ≤5 min.',
    // Reversível: em vez de uma pergunta a mais, um «Anular» durante 8 s.
    anular: (s) => s.reactivar(l.machineId),
    sucessoAnular: (_) => 'Suspensão anulada. O POS destranca em ≤5 min.',
    confirmacao: (
      titulo: 'Suspender ${_quem(l)}?',
      corpo:
          'O POS deste terminal tranca em até 5 min. '
          'Podes reactivar a qualquer momento.',
      confirmar: 'Suspender',
      destrutiva: true,
    ),
  );

  Future<void> _reactivar(Licenca l) => _accaoRemota(
        machineId: l.machineId,
        accao: (s) => s.reactivar(l.machineId),
        sucesso: (_) => 'Licença reactivada. O POS destranca em ≤5 min.',
      );

  Future<void> _cancelar(Licenca l) => _accaoRemota(
    machineId: l.machineId,
    accao: (s) => s.cancelar(l.machineId),
    sucesso: (_) => 'Licença terminada.',
    confirmacao: (
      titulo: 'Terminar a licença de ${_quem(l)}?',
      corpo:
          'Termina já: fica inactiva e com validade de hoje, e o '
          'terminal deixa de trabalhar. A linha não é apagada (fica o '
          'histórico).',
      confirmar: 'Terminar licença',
      destrutiva: true,
    ),
  );

  Future<void> _mudarTier(Licenca l, Tier novo) => _accaoRemota(
        machineId: l.machineId,
        accao: (s) => s.mudarTier(l.machineId, novo),
        sucesso: (r) => 'Plano alterado para ${r.tier.rotulo}. '
            'O POS actualiza em ≤5 min.',
        confirmacao: novo == Tier.base
            ? (
                titulo: 'Descer para Base?',
                corpo: 'O cliente perde Guias, Gestão e Gráficos. '
                    'As preferências ficam guardadas para retomar se voltar a Pro.',
                confirmar: 'Descer para Base',
                destrutiva: true,
              )
            : null,
      );

  Future<void> _verHistorial(Licenca l) async {
    final repo = ref.read(auditLicencasRepoProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => ModalHistorial(licencaId: l.id, repo: repo),
    );
  }

  /// **Acção manual e separada** (só o Cesar, após confirmar o pagamento): gera
  /// o `licenca.json` assinado para este terminal e abre a partilha. NUNCA é
  /// automática. Verifica colisão de série antes de gerar.
  Future<void> _gerarLicenca(Licenca l) async {
    final controller = TextEditingController(text: l.serie ?? '');
    final serie = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar pagamento e gerar licença'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gera o ficheiro licenca.json assinado para este terminal e '
              'abre a partilha. Cada terminal usa a sua própria série.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Série do terminal',
                hintText: 'ex.: FT-T1',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
    if (serie == null) return;

    try {
      final licencasRepo = ref.read(licencasRepoProvider);

      // A chave mestre da empresa tem de existir ANTES de se assinar: entra na
      // base da assinatura. Se já existe (outro terminal do mesmo NIF já a
      // criou), é essa que volta — a chamada é idempotente e é o que mantém os
      // terminais todos na mesma empresa.
      await ref.read(gerirLicencaProvider).atribuirChaveMestre(l.machineId);

      // Quem assina é o servidor. O Control não tem — nem volta a ter — chave
      // de assinatura nenhuma: manda o terminal e a série, e recebe de volta a
      // licença assinada com os campos exactos que entraram na assinatura.
      final conteudo = await gerarLicencaJsonComVerificacao(
        machineId: l.machineId,
        serie: serie,
        verificarColisao: (s, exceto) =>
            licencasRepo.licencaActivaComSerie(s, excetoMachineId: exceto),
        assinar: (machineId, s) =>
            ref.read(assinarLicencaProvider).assinar(machineId, serie: s),
      );
      await licencasRepo.definirSerie(l.id, serie.trim());
      // A activação passa pela Edge Function como qualquer outra mutação de
      // estado — assim fica auditada com o autor, e continua a funcionar no dia
      // em que a RLS de `licencas` fechar.
      if (!l.activa) {
        await ref.read(gerirLicencaProvider).reactivar(l.machineId);
      }

      final dir = await getTemporaryDirectory();
      final ficheiro = File('${dir.path}/licenca.json');
      await ficheiro.writeAsString('$conteudo\n');
      await Share.shareXFiles(
        [XFile(ficheiro.path)],
        text: r'Licença WashInvoice — colocar em C:\WashInvoice\licenca.json',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Licença gerada (série ${serie.trim()}).')),
      );
      _recarregar();
    } catch (e, st) {
      mostrarErro(e, stack: st);
    }
  }

  Future<void> _copiarMachineId(String machineId) async {
    await Clipboard.setData(ClipboardData(text: machineId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Machine ID copiado.')),
    );
  }

  Future<void> _copiarChaveMestre(String chave) async {
    await Clipboard.setData(ClipboardData(text: chave));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chave mestre copiada.')),
    );
  }

  void _verTodosAcessos(String machineId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ModalHistorico(machineId: machineId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<_DetalheData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) return Text(widget.machineId);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // PRO à esquerda do nome (#177); a app à direita. Aqui o
                    // badge da app aparece sempre, mesmo com o filtro fixo numa
                    // app — numa ficha individual saber de que app é o terminal
                    // é informação, não ruído de lista.
                    WiTierBadge(data.licenca.tier),
                    Flexible(
                      child: Text(
                        data.nomeCliente,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    WiAppBadge(data.licenca.app),
                  ],
                ),
                Text(
                  data.subtituloTerminal,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          FutureBuilder<_DetalheData>(
            future: _future,
            builder: (context, snapshot) {
              final l = snapshot.data?.licenca;
              if (l == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Center(child: WiBadgeEstado(l.estado)),
              );
            },
          ),
          // Apagar vive no menu e não num ícone da barra: é a única acção
          // deste ecrã sem volta, e um ícone à vista ao lado do estado é um
          // toque distraído à espera de acontecer.
          FutureBuilder<_DetalheData>(
            future: _future,
            builder: (context, snapshot) {
              final l = snapshot.data?.licenca;
              if (l == null) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                onSelected: (_) => _apagarLicenca(l.id, quem: _quem(l)),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'apagar',
                    child: Text('Apagar licença'),
                  ),
                ],
              );
            },
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
          final l = data.licenca;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _CardLicenca(
                data: data,
                onCopiar: _copiarMachineId,
                onCopiarChave: _copiarChaveMestre,
              ),
              const SizedBox(height: AppSpacing.md),
              if (data.ultimoPing != null) ...[
                _CardUltimoAcesso(data: data),
                const SizedBox(height: AppSpacing.md),
              ],
              _CardTermos(aceite: data.aceiteTermos, cliente: data.cliente),
              const SizedBox(height: AppSpacing.lg),
              _botaoRenovar(l, data.pedidoPendente),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Confirmar pagamento e gerar licença'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.azul700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _gerarLicenca(l),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const WiSeccaoTitulo(titulo: 'Controlo remoto'),
              const SizedBox(height: AppSpacing.sm),
              CardControloRemoto(
                licenca: l,
                ocupado: _aExecutar,
                onDarDias: (dias) => _darDias(l, dias),
                onSuspender: () => _suspender(l),
                onReactivar: () => _reactivar(l),
                onCancelar: () => _cancelar(l),
                onApagar: () => _apagarLicenca(l.id, quem: _quem(l)),
                onMudarTier: (t) => _mudarTier(l, t),
                onVerHistorial: () => _verHistorial(l),
              ),
              const SizedBox(height: AppSpacing.lg),
              CardPreferencias(licenca: l),
              // Card "Séries fiscais" — só aparece para clientes que emitem
              // (Pro/Legado); auto-esconde-se para Base.
              if (l.tier.temExtras) ...[
                const SizedBox(height: AppSpacing.lg),
                CardSeriesFiscais(licenca: l, onLicencaAlterada: _recarregar),
              ],
              const SizedBox(height: AppSpacing.xl),
              const WiSeccaoTitulo(titulo: 'Histórico de acessos'),
              const SizedBox(height: AppSpacing.sm),
              _HistoricoCurto(
                machineId: l.machineId,
                cliente: data.cliente,
                onVerTodos: () => _verTodosAcessos(l.machineId),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _botaoRenovar(Licenca l, PedidoRenovacao? pedido) {
    final prioritario = l.aExpirar || l.expirada;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: const Icon(Icons.event_available),
        label: Text(prioritario ? 'Renovar licença' : 'Renovar antecipadamente'),
        style: FilledButton.styleFrom(
          backgroundColor: prioritario ? AppColors.verde700 : AppColors.verde50,
          foregroundColor: prioritario ? Colors.white : AppColors.verde900,
          elevation: prioritario ? null : 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () => _marcarRenovacao(l, pedido),
      ),
    );
  }
}

/// Cabeçalho de card: ícone semântico + título.
class _CardHeader extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final Color? corIcone;
  const _CardHeader({required this.icone, required this.titulo, this.corIcone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icone, size: 18, color: corIcone ?? AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(titulo, style: AppText.h2),
        ],
      ),
    );
  }
}

class _CardLicenca extends StatelessWidget {
  final _DetalheData data;
  final void Function(String) onCopiar;
  final void Function(String) onCopiarChave;
  const _CardLicenca({
    required this.data,
    required this.onCopiar,
    required this.onCopiarChave,
  });

  String _validadeTexto(Licenca l) {
    final base = Dates.data(l.validade);
    if (l.expirada) {
      return '$base (expirada ${timeago.format(l.validade, locale: 'pt')})';
    }
    final dias = l.validade.difference(DateTime.now()).inDays;
    return '$base (faltam $dias dias)';
  }

  @override
  Widget build(BuildContext context) {
    final l = data.licenca;
    final machineCurto =
        l.machineId.length > 12 ? '${l.machineId.substring(0, 12)}…' : l.machineId;
    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
              icone: Icons.workspace_premium, titulo: 'Licença'),
          WiLinhaKV(rotulo: 'NIF', valor: l.nif),
          // Telefone do cliente — só quando preenchido no POS. Toque no ícone
          // abre o marcador do sistema.
          if (data.cliente?.telemovel != null &&
              data.cliente!.telemovel!.trim().isNotEmpty)
            WiLinhaKV(
              rotulo: 'Telefone',
              valor: data.cliente!.telemovel!.trim(),
              trailing: WiAccaoDeLinha(
                icone: Icons.phone,
                aoTocar: () => Acoes.ligarPara(data.cliente!.telemovel),
                descricao: 'Ligar ao cliente',
                cor: AppColors.verde,
              ),
            ),
          WiLinhaKV(rotulo: 'Plano', valor: l.planoLabel),
          WiLinhaKV(rotulo: 'Validade', valor: _validadeTexto(l)),
          if (l.serie != null) WiLinhaKV(rotulo: 'Série', valor: l.serie!),
          // A metade "empresa" do par. Só aparece depois de gerada a primeira
          // licença com chave mestre — nas instalações antigas ainda é null, e
          // uma linha a dizer "—" só levantava a pergunta de porquê.
          if (l.chaveMestre != null)
            WiLinhaKV(
              rotulo: 'Chave mestre',
              valor: l.chaveMestre!,
              mono: true,
              trailing: WiAccaoDeLinha(
                icone: Icons.copy,
                aoTocar: () => onCopiarChave(l.chaveMestre!),
                descricao: 'Copiar a chave mestre',
              ),
            ),
          WiLinhaKV(
            rotulo: 'Máquina',
            valor: machineCurto,
            mono: true,
            trailing: WiAccaoDeLinha(
              icone: Icons.copy,
              aoTocar: () => onCopiar(l.machineId),
              descricao: 'Copiar o identificador da máquina',
            ),
          ),
        ],
      ),
    );
  }
}

class _CardUltimoAcesso extends StatelessWidget {
  final _DetalheData data;
  const _CardUltimoAcesso({required this.data});

  /// Cidade que o sinal reporta. Sem método de geolocalização não há cidade
  /// para mostrar — devolve travessão em vez de uma cidade órfã que pareceria
  /// vinda de lado nenhum.
  static String _cidadeDoPing(Ping p) {
    if (p.metodoGeo == null || p.metodoGeo == 'nenhum') return '—';
    final cidade = Localidades.traduzir(p.cidade);
    return cidade.isEmpty ? '—' : cidade;
  }

  @override
  Widget build(BuildContext context) {
    final p = data.ultimoPing!;
    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(icone: Icons.podcasts, titulo: 'Último acesso'),
          // Data absoluta primeiro e o relativo entre parênteses: "há 2 dias"
          // sozinho não chega para se perceber se o terminal esteve parado no
          // fim-de-semana ou se falhou mesmo.
          WiLinhaKV(
            rotulo: 'Quando',
            valor: '${Dates.dataHora(p.criadoEm)} '
                '(${timeago.format(p.criadoEm, locale: 'pt')})',
          ),
          // Uma só linha para o sinal. Antes eram duas — "Sinal" (o método) e
          // "Sinal diz" (a cidade) — e pareciam dois sinais diferentes quando
          // é um só. Agora o método é a etiqueta: `GPS: Lisboa`.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Icon(Exibicao.iconeSinal(p.metodoGeo),
                          size: 16, color: Exibicao.corSinal(p.metodoGeo)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(Exibicao.rotuloSinal(p.metodoGeo),
                            style: AppText.label),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(_cidadeDoPing(p), style: AppText.bodyStrong),
                ),
              ],
            ),
          ),
          WiLinhaKV(
              rotulo: 'Loja',
              valor: (data.cliente?.localidade != null &&
                      data.cliente!.localidade!.trim().isNotEmpty)
                  ? data.cliente!.localidade!.trim()
                  : '—'),
          // IP público — só quando o ping o traz (pings antigos não têm).
          if (p.ipPublico != null && p.ipPublico!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  const SizedBox(
                    width: 100,
                    child: Row(
                      children: [
                        Icon(Icons.wifi,
                            size: 16, color: AppColors.textTertiary),
                        SizedBox(width: 6),
                        Text('IP', style: AppText.label),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        Text(p.ipPublico!.trim(), style: AppText.bodyStrong),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                const SizedBox(
                    width: 100, child: Text('Versão POS', style: AppText.label)),
                VersaoBadge(versao: p.versao, estado: data.estadoVersao),
                if (data.estadoVersao != EstadoVersao.atual &&
                    data.estadoVersao != EstadoVersao.desconhecida &&
                    data.versaoAtual != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text('(actual: v${data.versaoAtual})', style: AppText.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTermos extends StatelessWidget {
  final AceiteTermo? aceite;
  final Cliente? cliente;
  const _CardTermos({required this.aceite, required this.cliente});

  @override
  Widget build(BuildContext context) {
    final a = aceite;
    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icone: a != null ? Icons.verified_user : Icons.gpp_maybe,
            titulo: 'Termos aceites',
            corIcone: a != null ? AppColors.verde700 : AppColors.textTertiary,
          ),
          if (a == null)
            const Text('Termos ainda não aceites nesta máquina.',
                style: AppText.body)
          else ...[
            WiLinhaKV(
                rotulo: 'Data',
                valor: Dates.dataHora(a.dataAceite ?? a.criadoEm)),
            if (a.versaoTermos != null)
              WiLinhaKV(rotulo: 'Versão', valor: a.versaoTermos!),
            WiLinhaKV(
              rotulo: 'Localidade',
              valor: (cliente?.localidade != null &&
                      cliente!.localidade!.trim().isNotEmpty)
                  ? cliente!.localidade!.trim()
                  : (Localidades.traduzir(a.cidade).isEmpty
                      ? '—'
                      : Localidades.traduzir(a.cidade)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Histórico curto (até 5 acessos) num card único, com "Ver todos os acessos".
class _HistoricoCurto extends ConsumerWidget {
  final String machineId;
  final Cliente? cliente;
  final VoidCallback onVerTodos;
  const _HistoricoCurto({
    required this.machineId,
    required this.cliente,
    required this.onVerTodos,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(pingsRepoProvider);
    return FutureBuilder<List<Ping>>(
      future: repo.historico(machineId, limite: 5),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const WiCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return WiCard(
            child: Text(descreverErro(snapshot.error!),
                style: const TextStyle(color: AppColors.vermelho)),
          );
        }
        final pings = snapshot.data ?? [];
        if (pings.isEmpty) {
          return const WiCard(
            child: Text('Sem registos de acesso.', style: AppText.body),
          );
        }
        final localidade =
            (cliente?.localidade != null && cliente!.localidade!.trim().isNotEmpty)
                ? cliente!.localidade!.trim()
                : null;
        return WiCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < pings.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: AppColors.borda),
                _LinhaHistorico(ping: pings[i], localidade: localidade),
              ],
              const Divider(height: 1, thickness: 1, color: AppColors.borda),
              InkWell(
                onTap: onVerTodos,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: Text('Ver todos os acessos',
                      style: AppText.bodyStrong.copyWith(color: AppColors.azul700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LinhaHistorico extends StatelessWidget {
  final Ping ping;
  final String? localidade;
  const _LinhaHistorico({required this.ping, required this.localidade});

  @override
  Widget build(BuildContext context) {
    final cidade = Localidades.traduzir(ping.cidade);
    final rotulo =
        localidade ?? (cidade.isEmpty ? 'Localização desconhecida' : cidade);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.circle,
              size: 10,
              color: ping.cidade != null
                  ? AppColors.verde
                  : AppColors.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text('$rotulo · v${ping.versao ?? '?'}',
                style: AppText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(timeago.format(ping.criadoEm, locale: 'pt'),
              style: AppText.caption),
        ],
      ),
    );
  }
}

/// Modal com todos os acessos (até 120 pings retidos por máquina).
class _ModalHistorico extends ConsumerWidget {
  final String machineId;
  const _ModalHistorico({required this.machineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(pingsRepoProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return FutureBuilder<List<Ping>>(
          future: repo.historico(machineId, limite: 120),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final pings = snapshot.data ?? [];
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text('Todos os acessos (${pings.length})', style: AppText.h2),
                const SizedBox(height: AppSpacing.sm),
                ...pings.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          Icon(Icons.circle,
                              size: 10,
                              color: p.cidade != null
                                  ? AppColors.verde
                                  : AppColors.textTertiary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                                Localidades.traduzir(p.cidade).isEmpty
                                    ? 'Localização desconhecida'
                                    : Localidades.traduzir(p.cidade),
                                style: AppText.body),
                          ),
                          Text(Dates.dataHora(p.criadoEm), style: AppText.caption),
                        ],
                      ),
                    )),
              ],
            );
          },
        );
      },
    );
  }
}
