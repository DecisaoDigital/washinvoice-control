import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/acoes.dart';
import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/contexto_instalacoes.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../core/exibicao.dart';
import '../../core/localidades.dart';
import '../../core/widgets/widgets.dart';
import '../../models/cliente.dart';
import '../../models/pedido_ajuda.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';
import '../instalacoes/detalhe_cliente_screen.dart';
import 'pedidos_ajuda_screen.dart' show formatarDuracao;

class _DetalheData {
  final ContextoInstalacoes ctx;
  final Cliente? cliente;
  final Ping? ultimoPing;
  final EstadoLicencaResumo estadoLicenca;
  _DetalheData(this.ctx, this.cliente, this.ultimoPing, this.estadoLicenca);
}

/// Resumo do estado da licença do terminal (para o chip do card cliente).
enum EstadoLicencaResumo { activa, aExpirar, expirada, suspensa, semLicenca }

class DetalhePedidoAjudaScreen extends ConsumerStatefulWidget {
  final PedidoAjuda pedido;
  const DetalhePedidoAjudaScreen({super.key, required this.pedido});

  @override
  ConsumerState<DetalhePedidoAjudaScreen> createState() =>
      _DetalhePedidoAjudaScreenState();
}

class _DetalhePedidoAjudaScreenState
    extends ConsumerState<DetalhePedidoAjudaScreen> {
  late Future<_DetalheData> _future;
  late PedidoAjuda _pedido;

  @override
  void initState() {
    super.initState();
    _pedido = widget.pedido;
    _future = _carregar();
  }

  Future<_DetalheData> _carregar() async {
    final clientesRepo = ref.read(clientesRepoProvider);
    final licencasRepo = ref.read(licencasRepoProvider);
    final pingsRepo = ref.read(pingsRepoProvider);

    final clientesF = clientesRepo.listar();
    final licencasF = licencasRepo.listar();
    final pingsF = pingsRepo.ultimosPorInstalacao();
    await Future.wait([clientesF, licencasF, pingsF]);

    final ctx = ContextoInstalacoes.build(
      clientes: await clientesF,
      licencas: await licencasF,
      pings: await pingsF,
    );
    final cliente = ctx.clienteDe(
      clienteId: _pedido.clienteId,
      machineId: _pedido.machineId,
      nif: _pedido.nif,
    );
    final licenca = ctx.licencaDe(_pedido.machineId);
    final resumo = licenca == null
        ? EstadoLicencaResumo.semLicenca
        : EstadoLicencaResumo.values.byName(licenca.estado.name);

    return _DetalheData(ctx, cliente, ctx.pingDe(_pedido.machineId), resumo);
  }

  Future<void> _recarregar() async {
    setState(() { _future = _carregar(); });
    await _future;
  }

  Future<void> _resolver() async {
    await ref.read(pedidosAjudaRepoProvider).marcarResolvido(_pedido.id);
    setState(() => _pedido = _pedido.copyWith(resolvidoEm: DateTime.now()));
    await _recarregar();
  }

  Future<void> _copiar(String machineId) async {
    await Clipboard.setData(ClipboardData(text: machineId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Machine ID copiado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<_DetalheData>(
          future: _future,
          builder: (context, snapshot) {
            final nome = snapshot.data?.ctx
                    .nomeDe(machineId: _pedido.machineId, nif: _pedido.nif) ??
                (_pedido.nif != null ? 'NIF ${_pedido.nif}' : 'Pedido de ajuda');
            return Text(nome,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500));
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: _ChipEstadoPedido(resolvido: _pedido.resolvido)),
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
          final cliente = data.cliente;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _cardPedido(),
              const SizedBox(height: AppSpacing.md),
              _cardCliente(data),
              const SizedBox(height: AppSpacing.md),
              _cardUltimoPing(data),
              const SizedBox(height: AppSpacing.lg),
              if (cliente?.telemovel != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.phone),
                    label: const Text('Ligar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.azul700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Acoes.ligarPara(cliente!.telemovel),
                  ),
                ),
              if (cliente?.email != null) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Enviar email'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.azul700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Acoes.enviarEmail(cliente!.email,
                        assunto: 'Re: pedido de ajuda WashInvoice'),
                  ),
                ),
              ],
              if (!_pedido.resolvido) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Marcar como resolvido'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.verde700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _resolver,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        DetalheClienteScreen(machineId: _pedido.machineId),
                  )),
                  child: const Text('Ver ficha completa do cliente'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cardPedido() {
    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(icone: Icons.help_outline, titulo: 'Pedido',
              cor: AppColors.laranja700),
          if (_pedido.notas != null && _pedido.notas!.trim().isNotEmpty)
            SelectableText(_pedido.notas!.trim(), style: AppText.body)
          else
            Text('(sem notas)',
                style: AppText.body.copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: AppSpacing.sm),
          WiLinhaKV(
            rotulo: 'Criado em',
            valor:
                '${Dates.dataHora(_pedido.criadoEm)} · há ${timeago.format(_pedido.criadoEm, locale: 'pt')}',
          ),
          if (_pedido.resolvido)
            WiLinhaKV(
              rotulo: 'Resolvido em',
              valor:
                  '${Dates.dataHora(_pedido.resolvidoEm!)} · duração ${formatarDuracao(_pedido.duracao)}',
            ),
        ],
      ),
    );
  }

  Widget _cardCliente(_DetalheData data) {
    final machineCurto = _pedido.machineId.length > 12
        ? '${_pedido.machineId.substring(0, 12)}…'
        : _pedido.machineId;
    final loja = (data.cliente?.localidade != null &&
            data.cliente!.localidade!.trim().isNotEmpty)
        ? data.cliente!.localidade!.trim()
        : '—';
    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(icone: Icons.store_outlined, titulo: 'Cliente / Terminal'),
          WiLinhaKV(
            rotulo: 'Nome',
            valor: data.ctx.nomeDe(machineId: _pedido.machineId, nif: _pedido.nif),
          ),
          WiLinhaKV(rotulo: 'NIF', valor: _pedido.nif ?? '—'),
          WiLinhaKV(rotulo: 'Localidade', valor: loja),
          WiLinhaKV(
            rotulo: 'Máquina',
            valor: machineCurto,
            mono: true,
            trailing: WiAccaoDeLinha(
              icone: Icons.copy,
              aoTocar: () => _copiar(_pedido.machineId),
              descricao: 'Copiar o identificador da máquina',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                const SizedBox(
                    width: 100, child: Text('Licença', style: AppText.label)),
                _ChipLicenca(data.estadoLicenca),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardUltimoPing(_DetalheData data) {
    final p = data.ultimoPing;
    if (p == null) {
      return const WiCard(
        child: Text('Sem pings deste terminal.', style: AppText.body),
      );
    }
    final cidade = Localidades.traduzir(p.cidade);
    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(icone: Icons.podcasts, titulo: 'Último ping'),
          WiLinhaKV(
            rotulo: 'Quando',
            valor: '${Dates.dataHora(p.criadoEm)} '
                '(${timeago.format(p.criadoEm, locale: 'pt')})',
          ),
          // Método e cidade numa só linha, como no detalhe do cliente: duas
          // linhas separadas pareciam dois sinais diferentes.
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
                  child: Text(
                    (p.metodoGeo == null || p.metodoGeo == 'nenhum' ||
                            cidade.isEmpty)
                        ? '—'
                        : cidade,
                    style: AppText.bodyStrong,
                  ),
                ),
              ],
            ),
          ),
          WiLinhaKV(rotulo: 'Versão POS', valor: 'v${p.versao ?? '?'}'),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final Color? cor;
  const _Header({required this.icone, required this.titulo, this.cor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icone, size: 18, color: cor ?? AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(titulo, style: AppText.h2),
        ],
      ),
    );
  }
}

class _ChipEstadoPedido extends StatelessWidget {
  final bool resolvido;
  const _ChipEstadoPedido({required this.resolvido});

  @override
  Widget build(BuildContext context) {
    final fundo = resolvido ? AppColors.verde100 : AppColors.laranja100;
    final forte = resolvido ? AppColors.verde900 : AppColors.laranja900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: fundo, borderRadius: AppRadius.pillAll),
      child: Text(
        resolvido ? 'Resolvido' : 'Aberto',
        style: TextStyle(color: forte, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ChipLicenca extends StatelessWidget {
  final EstadoLicencaResumo estado;
  const _ChipLicenca(this.estado);

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color fundo;
    late final Color forte;
    switch (estado) {
      case EstadoLicencaResumo.activa:
        label = 'Activa';
        fundo = AppColors.verde100;
        forte = AppColors.verde900;
      case EstadoLicencaResumo.aExpirar:
        label = 'A expirar';
        fundo = AppColors.laranja100;
        forte = AppColors.laranja900;
      case EstadoLicencaResumo.expirada:
        label = 'Expirada';
        fundo = AppColors.vermelho100;
        forte = AppColors.vermelho900;
      case EstadoLicencaResumo.suspensa:
        label = 'Suspensa';
        fundo = AppColors.fundo;
        forte = AppColors.textSecondary;
      case EstadoLicencaResumo.semLicenca:
        label = 'Sem licença';
        fundo = AppColors.fundo;
        forte = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: fundo, borderRadius: AppRadius.pillAll),
      child: Text(label,
          style:
              TextStyle(color: forte, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
