import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../core/estado_ui.dart';
import '../../core/versoes.dart';
import '../../models/aceite_termo.dart';
import '../../models/licenca.dart';
import '../../models/pedido_renovacao.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';

class _DetalheData {
  final Licenca licenca;
  final Ping? ultimoPing;
  final PedidoRenovacao? pedidoPendente;
  final AceiteTermo? aceiteTermos;
  final EstadoVersao estadoVersao;
  final String? versaoAtual;
  _DetalheData(
    this.licenca,
    this.ultimoPing,
    this.pedidoPendente,
    this.aceiteTermos,
    this.estadoVersao,
    this.versaoAtual,
  );
}

class DetalheClienteScreen extends ConsumerStatefulWidget {
  final String nif;
  const DetalheClienteScreen({super.key, required this.nif});

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

    final licenca = await licencasRepo.porNif(widget.nif);
    if (licenca == null) {
      throw Exception('Licença não encontrada para o NIF ${widget.nif}.');
    }
    final historico = await pingsRepo.historico(licenca.machineId, limite: 1);
    final pedido = await pedidosRepo.pendentePorNif(widget.nif);
    final aceite = await aceitesRepo.ultimoPorMachineId(licenca.machineId);

    // Referência global de versão: a mais evoluída entre todas as instalações.
    final todosUltimos = await pingsRepo.ultimosPorInstalacao();
    final classV = ClassificadorVersoes(todosUltimos.map((p) => p.versao));
    final ultimoPing = historico.isNotEmpty ? historico.first : null;

    return _DetalheData(
      licenca,
      ultimoPing,
      pedido,
      aceite,
      classV.estadoDe(ultimoPing?.versao),
      classV.versaoAtual,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<_DetalheData>(
          future: _future,
          builder: (context, snapshot) {
            final l = snapshot.data?.licenca;
            return Text(l?.nome ?? widget.nif);
          },
        ),
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
            padding: const EdgeInsets.all(16),
            children: [
              _CardInfo(
                titulo: 'Licença',
                linhas: [
                  _Linha('NIF', l.nif),
                  _Linha('Plano', l.plano),
                  _Linha('Validade', Dates.data(l.validade)),
                  _Linha('Machine ID', l.machineId, monospace: true),
                ],
                extra: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Text(
                        'Estado',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      ChipEstado(l.estado),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (data.ultimoPing != null) ...[
                _CardInfo(
                  titulo: 'Último acesso',
                  linhas: [
                    _Linha('Data',
                        timeago.format(data.ultimoPing!.criadoEm, locale: 'pt')),
                    _Linha('Cidade', data.ultimoPing!.cidade ?? '—'),
                    _Linha('Geoloc.', data.ultimoPing!.metodoGeo ?? '—'),
                  ],
                  extra: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 100,
                          child: Text(
                            'Versão',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        VersaoBadge(
                          versao: data.ultimoPing!.versao,
                          estado: data.estadoVersao,
                        ),
                        if (data.estadoVersao != EstadoVersao.atual &&
                            data.estadoVersao != EstadoVersao.desconhecida &&
                            data.versaoAtual != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(atual: v${data.versaoAtual})',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _CardTermos(aceite: data.aceiteTermos),
              const SizedBox(height: 12),
              if (l.expirada || l.aExpirar)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.workspace_premium),
                      label: const Text('Marcar como pago e renovar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.roxo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _marcarRenovacao(l, data.pedidoPendente),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(l.activa ? Icons.block : Icons.check_circle),
                  label: Text(
                    l.activa ? 'Suspender licença' : 'Activar licença',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        l.activa ? AppColors.vermelho : AppColors.verde,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => _toggleActiva(l),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Histórico de acessos',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _HistoricoPings(machineId: l.machineId),
            ],
          );
        },
      ),
    );
  }
}

class _CardTermos extends StatelessWidget {
  final AceiteTermo? aceite;
  const _CardTermos({required this.aceite});

  @override
  Widget build(BuildContext context) {
    final a = aceite;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  a != null ? Icons.verified_user : Icons.gpp_maybe,
                  color: a != null ? AppColors.verde : AppColors.textTertiary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Termos & Condições',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (a == null)
              const Text(
                'Termos ainda não aceites nesta máquina.',
                style: TextStyle(color: AppColors.textTertiary),
              )
            else ...[
              _LinhaTermo(
                'Aceite em',
                Dates.dataHora(a.dataAceite ?? a.criadoEm),
              ),
              if (a.versaoTermos != null)
                _LinhaTermo('Versão', a.versaoTermos!),
              if (a.cidade != null) _LinhaTermo('Cidade', a.cidade!),
              if (a.ip != null) _LinhaTermo('IP', a.ip!),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinhaTermo extends StatelessWidget {
  final String rotulo;
  final String valor;
  const _LinhaTermo(this.rotulo, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              rotulo,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}

class _HistoricoPings extends ConsumerWidget {
  final String machineId;
  const _HistoricoPings({required this.machineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(pingsRepoProvider);
    return FutureBuilder<List<Ping>>(
      future: repo.historico(machineId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text(
            descreverErro(snapshot.error!),
            style: const TextStyle(color: AppColors.vermelho),
          );
        }
        final pings = snapshot.data ?? [];
        if (pings.isEmpty) {
          return const Text(
            'Sem registos de acesso.',
            style: TextStyle(color: AppColors.textTertiary),
          );
        }
        return Column(
          children: pings.map((p) => _LinhaPing(p)).toList(),
        );
      },
    );
  }
}

class _LinhaPing extends StatelessWidget {
  final Ping ping;
  const _LinhaPing(this.ping);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.circle,
        size: 10,
        color: ping.cidade != null ? AppColors.verde : AppColors.textTertiary,
      ),
      title: Text(ping.cidade ?? 'Localização desconhecida'),
      subtitle: Text(Dates.dataHora(ping.criadoEm)),
      trailing: Text(
        'v${ping.versao ?? '?'}',
        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
      ),
    );
  }
}

class _Linha {
  final String rotulo;
  final String valor;
  final bool monospace;
  _Linha(this.rotulo, this.valor, {this.monospace = false});
}

class _CardInfo extends StatelessWidget {
  final String titulo;
  final List<_Linha> linhas;
  final Widget? extra;

  const _CardInfo({required this.titulo, required this.linhas, this.extra});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...linhas.map(
              (l) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        l.rotulo,
                        style:
                            const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: l.monospace
                          ? SelectableText(
                              l.valor,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            )
                          : Text(l.valor),
                    ),
                  ],
                ),
              ),
            ),
            if (extra != null) extra!,
          ],
        ),
      ),
    );
  }
}
