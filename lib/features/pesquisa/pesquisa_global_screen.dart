import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/contexto_instalacoes.dart';
import '../../core/erros.dart';
import '../../core/localidades.dart';
import '../../core/widgets/widgets.dart';
import '../../models/cliente.dart';
import '../../models/licenca.dart';
import '../../models/pedido_ajuda.dart';
import '../../models/ping.dart';
import '../../models/sugestao.dart';
import '../../repositories/providers.dart';
import '../ativacao/ativar_instalacao_screen.dart';
import '../instalacoes/detalhe_cliente_screen.dart';
import '../pedidos_ajuda/detalhe_pedido_ajuda_screen.dart';
import '../sugestoes/detalhe_sugestao_screen.dart';

/// Dados carregados uma vez; a filtragem é em memória (dados pequenos, regra do
/// projecto). O debounce evita reconstruções a cada tecla.
class _PesquisaData {
  final List<Cliente> clientes;
  final List<Licenca> licencas;
  final List<Ping> pings;
  final List<PedidoAjuda> pedidos;
  final List<Sugestao> sugestoes;
  final ContextoInstalacoes ctx;
  _PesquisaData(this.clientes, this.licencas, this.pings, this.pedidos,
      this.sugestoes, this.ctx);
}

bool _m(String? campo, String q) =>
    campo != null && campo.toLowerCase().contains(q);

class PesquisaGlobalScreen extends ConsumerStatefulWidget {
  const PesquisaGlobalScreen({super.key});

  @override
  ConsumerState<PesquisaGlobalScreen> createState() =>
      _PesquisaGlobalScreenState();
}

class _PesquisaGlobalScreenState extends ConsumerState<PesquisaGlobalScreen> {
  late Future<_PesquisaData> _future;
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<_PesquisaData> _carregar() async {
    // **Sem filtro de app de propósito.** A pesquisa global é o escape à
    // vista filtrada: se o Cesar tem o selector em Fist e procura um cliente
    // POS, quer encontrá-lo, não receber "sem resultados". Os badges de app
    // nos resultados dizem de onde é cada linha.
    final clientesF = ref.read(clientesRepoProvider).listar();
    final licencasF = ref.read(licencasRepoProvider).listar();
    final pingsF = ref.read(pingsRepoProvider).ultimosPorInstalacao();
    final abertosF = ref.read(pedidosAjudaRepoProvider).listarAbertos();
    final histF = ref.read(pedidosAjudaRepoProvider).listarHistorico();
    final porLerF = ref.read(sugestoesRepoProvider).listarPorLer();
    final arquivoF = ref.read(sugestoesRepoProvider).listarArquivo();
    await Future.wait(
        [clientesF, licencasF, pingsF, abertosF, histF, porLerF, arquivoF]);

    final clientes = await clientesF;
    final licencas = await licencasF;
    final pings = await pingsF;
    return _PesquisaData(
      clientes,
      licencas,
      pings,
      [...await abertosF, ...await histF],
      [...await porLerF, ...await arquivoF],
      ContextoInstalacoes.build(
          clientes: clientes, licencas: licencas, pings: pings),
    );
  }

  void _aoEscrever(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = v.trim().toLowerCase());
    });
  }

  void _abrir(Widget ecra) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ecra));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          onChanged: _aoEscrever,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'Procurar em toda a base…',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            border: InputBorder.none,
          ),
        ),
      ),
      body: FutureBuilder<_PesquisaData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErroView(
                erro: snapshot.error!,
                onRetry: () => setState(() { _future = _carregar(); }));
          }
          if (_query.length < 2) {
            return const WiEmptyState(
              icone: Icons.search,
              titulo: 'Pesquisa global',
              mensagem: 'Escreve para procurar em toda a tua base.',
            );
          }
          return _resultados(snapshot.data!);
        },
      ),
    );
  }

  Widget _resultados(_PesquisaData d) {
    final q = _query;
    final clientes = d.clientes
        .where((c) =>
            _m(c.nome, q) ||
            _m(c.nif, q) ||
            _m(c.email, q) ||
            _m(c.telemovel, q) ||
            _m(c.notas, q) ||
            _m(c.localidade, q))
        .toList();
    final licencas = d.licencas
        .where((l) =>
            _m(l.nif, q) ||
            _m(l.nome, q) ||
            _m(l.machineId, q) ||
            _m(l.serie, q))
        .toList();
    final pings = d.pings
        .where((p) => _m(p.nif, q) || _m(p.machineId, q) || _m(p.cidade, q))
        .toList();
    final pedidos = d.pedidos
        .where((p) => _m(p.nif, q) || _m(p.machineId, q) || _m(p.notas, q))
        .toList();
    final sugestoes = d.sugestoes
        .where((s) => _m(s.nif, q) || _m(s.machineId, q) || _m(s.texto, q))
        .toList();

    final total = clientes.length +
        licencas.length +
        pings.length +
        pedidos.length +
        sugestoes.length;
    if (total == 0) {
      return WiEmptyState(
        icone: Icons.search_off,
        titulo: 'Sem resultados',
        mensagem: 'Nada encontrado para «$_query».',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _grupo('Clientes', clientes.length, [
          for (final c in clientes)
            _ResultadoCard(
              icone: Icons.store_outlined,
              titulo: c.nome,
              subtitulo:
                  'NIF ${c.nif}${c.localidade != null ? ' · ${Localidades.traduzir(c.localidade)}' : ''}',
              onTap: () => _abrirCliente(d, c),
            ),
        ]),
        _grupo('Licenças', licencas.length, [
          for (final l in licencas)
            _ResultadoCard(
              icone: Icons.workspace_premium,
              app: l.app,
              titulo: d.ctx.nomeDe(machineId: l.machineId, nif: l.nif),
              subtitulo:
                  '${l.planoLabel}${l.serie != null ? ' · série ${l.serie}' : ''}',
              onTap: () => _abrir(
                  DetalheClienteScreen(machineId: l.machineId)),
            ),
        ]),
        _grupo('Terminais (pings)', pings.length, [
          for (final p in pings)
            _ResultadoCard(
              icone: Icons.podcasts,
              app: p.app,
              titulo: d.ctx.nomeDe(machineId: p.machineId, nif: p.nif),
              subtitulo: Localidades.traduzir(p.cidade).isEmpty
                  ? 'v${p.versao ?? '?'}'
                  : '${Localidades.traduzir(p.cidade)} · v${p.versao ?? '?'}',
              onTap: () => _abrirPing(d, p),
            ),
        ]),
        _grupo('Pedidos de ajuda', pedidos.length, [
          for (final p in pedidos)
            _ResultadoCard(
              icone: Icons.help_outline,
              app: p.app,
              titulo: d.ctx.nomeDe(machineId: p.machineId, nif: p.nif),
              subtitulo: p.resolvido ? 'Resolvido' : 'Aberto',
              onTap: () => _abrir(DetalhePedidoAjudaScreen(pedido: p)),
            ),
        ]),
        _grupo('Sugestões', sugestoes.length, [
          for (final s in sugestoes)
            _ResultadoCard(
              icone: Icons.lightbulb_outline,
              app: s.app,
              titulo: d.ctx.nomeDe(machineId: s.machineId ?? '', nif: s.nif),
              subtitulo: s.texto,
              onTap: () => _abrir(DetalheSugestaoScreen(sugestao: s)),
            ),
        ]),
      ],
    );
  }

  void _abrirCliente(_PesquisaData d, Cliente c) {
    // Cliente não tem machine_id directo — abre o detalhe da 1ª licença dele.
    final lic = d.licencas.where((l) => l.clienteId == c.id || l.nif == c.nif);
    if (lic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${c.nome} ainda não tem licença/terminal.')),
      );
      return;
    }
    _abrir(DetalheClienteScreen(machineId: lic.first.machineId));
  }

  void _abrirPing(_PesquisaData d, Ping p) {
    if (d.ctx.licencaDe(p.machineId) != null) {
      _abrir(DetalheClienteScreen(machineId: p.machineId));
    } else {
      _abrir(AtivarInstalacaoScreen(ping: p));
    }
  }

  Widget _grupo(String titulo, int n, List<Widget> cards) {
    if (n == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
              top: AppSpacing.sm, bottom: AppSpacing.sm),
          child: Text('$titulo ($n)', style: AppText.label),
        ),
        ...cards.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: c,
            )),
      ],
    );
  }
}

class _ResultadoCard extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  /// App do resultado (`null` para os que não pertencem a nenhuma, como os
  /// clientes). Ao contrário das listas, aqui o badge aparece sempre: a
  /// pesquisa ignora o filtro global, portanto é a única pista da origem.
  final String? app;

  const _ResultadoCard({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.app,
  });

  @override
  Widget build(BuildContext context) {
    return WiCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icone, size: 20, color: AppColors.azul700),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (app != null) ...[
                      WiAppBadge(app!),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Text(titulo,
                          style: AppText.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                Text(subtitulo,
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              size: 20, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
