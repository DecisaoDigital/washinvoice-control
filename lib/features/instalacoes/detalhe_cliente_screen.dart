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
import '../../core/contexto_instalacoes.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../core/exibicao.dart';
import '../../core/localidades.dart';
import '../../core/versoes.dart';
import '../../core/widgets/widgets.dart';
import '../../models/aceite_termo.dart';
import '../../models/cliente.dart';
import '../../models/licenca.dart';
import '../../models/pedido_renovacao.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';
import '../../services/licenca_emissao.dart';

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
  );

  String get nomeCliente {
    if (cliente != null) return cliente!.nome;
    if (licenca.nome != null && licenca.nome!.trim().isNotEmpty) {
      return licenca.nome!.trim();
    }
    return 'NIF ${licenca.nif}';
  }

  String get subtituloTerminal =>
      total > 1 ? 'Terminal $ordem de $total' : 'Terminal único';
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
    final pedido = await pedidosRepo.pendentePorNif(licenca.nif);
    final aceite = await aceitesRepo.ultimoPorMachineId(licenca.machineId);

    final todosUltimos = await pingsRepo.ultimosPorInstalacao();
    final todasLicencas = await licencasRepo.listar();
    final clientes = await clientesRepo.listar();
    final classV = ClassificadorVersoes(todosUltimos.map((p) => p.versao));
    final ultimoPing = historico.isNotEmpty ? historico.first : null;

    final ctx = ContextoInstalacoes.build(
        clientes: clientes, licencas: todasLicencas, pings: todosUltimos);
    final ordemTotal = ctx.ordemDe(licenca.machineId);
    final cliente = ctx.clienteDe(
        clienteId: licenca.clienteId,
        machineId: licenca.machineId,
        nif: licenca.nif);

    return _DetalheData(
      licenca,
      ultimoPing,
      pedido,
      aceite,
      classV.estadoDe(ultimoPing?.versao),
      classV.versaoAtual,
      cliente,
      ordemTotal?.$1 ?? 1,
      ordemTotal?.$2 ?? 1,
    );
  }

  void _recarregar() {
    setState(() => _future = _carregar());
  }

  Future<void> _marcarRenovacao(Licenca l, PedidoRenovacao? pedido) async {
    final agora = DateTime.now();
    final novaData = await showDatePicker(
      context: context,
      initialDate: l.expirada ? agora.add(const Duration(days: 30)) : l.validade,
      firstDate: agora.subtract(const Duration(days: 1)),
      lastDate: agora.add(const Duration(days: 365 * 5)),
      helpText: 'Nova data de validade',
    );
    if (novaData == null) return;

    try {
      final licencasRepo = ref.read(licencasRepoProvider);
      final pedidosRepo = ref.read(pedidosRepoProvider);
      await licencasRepo.actualizar(
        l.copyWith(validade: novaData, activa: true),
      );
      if (pedido != null) {
        await pedidosRepo.confirmar(pedido.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Licença renovada até ${Dates.data(novaData)}')),
      );
      _recarregar();
    } catch (e, st) {
      mostrarErro(e, stack: st);
    }
  }

  Future<void> _toggleActiva(Licenca l) async {
    try {
      final licencasRepo = ref.read(licencasRepoProvider);
      await licencasRepo.activar(l.id, activa: !l.activa);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.activa ? 'Licença suspensa.' : 'Licença activada.'),
        ),
      );
      _recarregar();
    } catch (e, st) {
      mostrarErro(e, stack: st);
    }
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
      final conteudo = await gerarLicencaJsonComVerificacao(
        licenca: l,
        serie: serie,
        verificarColisao: (s, exceto) =>
            licencasRepo.licencaActivaComSerie(s, excetoMachineId: exceto),
      );
      await licencasRepo.definirSerie(l.id, serie.trim());
      if (!l.activa) await licencasRepo.activar(l.id, activa: true);

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
                Text(data.nomeCliente,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
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
              _CardLicenca(data: data, onCopiar: _copiarMachineId),
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
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(l.activa ? Icons.block : Icons.check_circle),
                  label: Text(
                      l.activa ? 'Suspender licença' : 'Reactivar licença'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        l.activa ? AppColors.vermelho : AppColors.verde,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _toggleActiva(l),
                ),
              ),
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
  const _CardLicenca({required this.data, required this.onCopiar});

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
          WiLinhaKV(rotulo: 'Plano', valor: l.planoLabel),
          WiLinhaKV(rotulo: 'Validade', valor: _validadeTexto(l)),
          if (l.serie != null) WiLinhaKV(rotulo: 'Série', valor: l.serie!),
          WiLinhaKV(
            rotulo: 'Máquina',
            valor: machineCurto,
            mono: true,
            trailing: InkWell(
              onTap: () => onCopiar(l.machineId),
              child: const Icon(Icons.copy,
                  size: 18, color: AppColors.textTertiary),
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

  @override
  Widget build(BuildContext context) {
    final p = data.ultimoPing!;
    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(icone: Icons.podcasts, titulo: 'Último acesso'),
          WiLinhaKV(
              rotulo: 'Quando',
              valor: timeago.format(p.criadoEm, locale: 'pt')),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 100, child: Text('Sinal', style: AppText.label)),
                Icon(Exibicao.iconeSinal(p.metodoGeo),
                    size: 16, color: Exibicao.corSinal(p.metodoGeo)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(Exibicao.descricaoSinal(p.metodoGeo),
                      style: AppText.bodyStrong),
                ),
              ],
            ),
          ),
          WiLinhaKV(
              rotulo: 'Sinal diz',
              valor: Localidades.traduzir(p.cidade).isEmpty
                  ? '—'
                  : Localidades.traduzir(p.cidade)),
          WiLinhaKV(
              rotulo: 'Loja',
              valor: (data.cliente?.localidade != null &&
                      data.cliente!.localidade!.trim().isNotEmpty)
                  ? data.cliente!.localidade!.trim()
                  : '—'),
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
