import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/app_colors.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../core/estado_ui.dart';
import '../../core/versoes.dart';
import '../../models/licenca.dart';
import '../../models/ping.dart';
import '../../repositories/providers.dart';
import 'detalhe_cliente_screen.dart';

class _InstalacoesData {
  final List<Licenca> licencas;
  final Map<String, Ping> pingPorMachine;
  _InstalacoesData(this.licencas, this.pingPorMachine);
}

class InstalacoesScreen extends ConsumerStatefulWidget {
  const InstalacoesScreen({super.key});

  @override
  ConsumerState<InstalacoesScreen> createState() => _InstalacoesScreenState();
}

class _InstalacoesScreenState extends ConsumerState<InstalacoesScreen> {
  late Future<_InstalacoesData> _future;

  // Pesquisa + filtros são aplicados **client-side** (R1): a lista já é toda
  // carregada para o dashboard/instalações e o volume actual é pequeno. Se um
  // dia passar de umas centenas de instalações, migrar a filtragem para uma
  // RPC/consulta paginada no Supabase.
  String _filtro = '';
  EstadoLicenca? _estado;
  String? _versao;
  String? _cidade;
  int? _semPingDias; // 3 / 7 / 14 dias sem ping (null = qualquer)

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<_InstalacoesData> _carregar() async {
    final licencasRepo = ref.read(licencasRepoProvider);
    final pingsRepo = ref.read(pingsRepoProvider);
    final results = await Future.wait([
      licencasRepo.listar(),
      pingsRepo.ultimosPorInstalacao(),
    ]);
    final licencas = results[0] as List<Licenca>;
    final pings = results[1] as List<Ping>;
    final mapa = {for (final p in pings) p.machineId: p};
    return _InstalacoesData(licencas, mapa);
  }

  Future<void> _recarregar() async {
    setState(() => _future = _carregar());
    await _future;
  }

  List<Licenca> _filtrar(_InstalacoesData data) {
    final q = _filtro.trim().toLowerCase();
    final agora = DateTime.now();
    return data.licencas.where((l) {
      // Pesquisa por texto: nome, NIF ou machine_id.
      if (q.isNotEmpty) {
        final bate = (l.nome?.toLowerCase().contains(q) ?? false) ||
            l.nif.toLowerCase().contains(q) ||
            l.machineId.toLowerCase().contains(q);
        if (!bate) return false;
      }
      if (_estado != null && l.estado != _estado) return false;

      final ping = data.pingPorMachine[l.machineId];
      if (_versao != null && ping?.versao != _versao) return false;
      if (_cidade != null && ping?.cidade != _cidade) return false;
      if (_semPingDias != null) {
        // "Sem ping há N dias": sem ping algum, ou último ping mais antigo que N.
        final semPing = ping == null ||
            agora.difference(ping.criadoEm).inDays >= _semPingDias!;
        if (!semPing) return false;
      }
      return true;
    }).toList();
  }

  String _labelEstado(EstadoLicenca e) {
    switch (e) {
      case EstadoLicenca.activa:
        return 'Activa';
      case EstadoLicenca.aExpirar:
        return 'A expirar';
      case EstadoLicenca.expirada:
        return 'Expirada';
      case EstadoLicenca.suspensa:
        return 'Suspensa';
    }
  }

  /// Barra horizontal de filtros. As opções de versão/cidade vêm dos dados
  /// carregados (pings), por isso é construída dentro do FutureBuilder.
  Widget _barraFiltros(List<String> versoes, List<String> cidades) {
    final temFiltro = _estado != null ||
        _versao != null ||
        _cidade != null ||
        _semPingDias != null;
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _filtroDropdown<EstadoLicenca>(
              rotulo: 'Estado',
              valor: _estado,
              opcoes: EstadoLicenca.values,
              label: _labelEstado,
              onChanged: (v) => setState(() => _estado = v),
            ),
            _filtroDropdown<String>(
              rotulo: 'Versão',
              valor: _versao,
              opcoes: versoes,
              label: (v) => 'v$v',
              onChanged: (v) => setState(() => _versao = v),
            ),
            _filtroDropdown<String>(
              rotulo: 'Cidade',
              valor: _cidade,
              opcoes: cidades,
              label: (v) => v,
              onChanged: (v) => setState(() => _cidade = v),
            ),
            _filtroDropdown<int>(
              rotulo: 'Sem ping',
              valor: _semPingDias,
              opcoes: const [3, 7, 14],
              label: (n) => '$n+ dias',
              onChanged: (v) => setState(() => _semPingDias = v),
            ),
            if (temFiltro)
              TextButton.icon(
                onPressed: () => setState(() {
                  _estado = null;
                  _versao = null;
                  _cidade = null;
                  _semPingDias = null;
                }),
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Limpar'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filtroDropdown<T>({
    required String rotulo,
    required T? valor,
    required List<T> opcoes,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    final activo = valor != null;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: activo ? AppColors.azul.withValues(alpha: 0.08) : null,
        border: Border.all(
          color: activo
              ? AppColors.azul
              : AppColors.textTertiary.withValues(alpha: 0.4),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: valor,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: [
            DropdownMenuItem<T?>(
              value: null,
              child: Text('$rotulo: todos'),
            ),
            ...opcoes.map(
              (o) => DropdownMenuItem<T?>(value: o, child: Text(label(o))),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instalações')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchBar(
              hintText: 'Procurar por nome, NIF ou machine ID',
              leading: const Icon(Icons.search),
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
                final classV = ClassificadorVersoes(
                  data.pingPorMachine.values.map((p) => p.versao),
                );
                final versoes = data.pingPorMachine.values
                    .map((p) => p.versao)
                    .whereType<String>()
                    .toSet()
                    .toList()
                  ..sort();
                final cidades = data.pingPorMachine.values
                    .map((p) => p.cidade)
                    .whereType<String>()
                    .toSet()
                    .toList()
                  ..sort();
                final licencas = _filtrar(data);
                return Column(
                  children: [
                    _barraFiltros(versoes, cidades),
                    Expanded(
                      child: licencas.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhuma instalação corresponde aos filtros.',
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _recarregar,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: licencas.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final l = licencas[i];
                                  final ultimoPing =
                                      data.pingPorMachine[l.machineId];
                                  return _CartaoInstalacao(
                                    licenca: l,
                                    ultimoPing: ultimoPing,
                                    estadoVersao:
                                        classV.estadoDe(ultimoPing?.versao),
                                    onTap: () {
                                      Navigator.of(context)
                                          .push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  DetalheClienteScreen(
                                                machineId: l.machineId,
                                              ),
                                            ),
                                          )
                                          .then((_) => _recarregar());
                                    },
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
    );
  }
}

class _CartaoInstalacao extends StatelessWidget {
  final Licenca licenca;
  final Ping? ultimoPing;
  final EstadoVersao estadoVersao;
  final VoidCallback onTap;

  const _CartaoInstalacao({
    required this.licenca,
    required this.ultimoPing,
    required this.estadoVersao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              BadgeEstado(licenca.estado),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      licenca.nome ?? licenca.nif,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${licenca.plano} · expira ${Dates.data(licenca.validade)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (ultimoPing != null)
                      Text(
                        '${ultimoPing!.cidade ?? ''} · último acesso ${timeago.format(ultimoPing!.criadoEm, locale: 'pt')}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              if (ultimoPing != null) ...[
                VersaoBadge(versao: ultimoPing!.versao, estado: estadoVersao),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
