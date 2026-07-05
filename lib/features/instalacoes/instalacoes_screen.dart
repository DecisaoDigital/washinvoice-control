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
  String _filtro = '';

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

  List<Licenca> _filtrar(List<Licenca> licencas) {
    if (_filtro.trim().isEmpty) return licencas;
    final q = _filtro.toLowerCase();
    return licencas.where((l) {
      return (l.nome?.toLowerCase().contains(q) ?? false) ||
          l.nif.toLowerCase().contains(q) ||
          l.machineId.toLowerCase().contains(q);
    }).toList();
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
                final licencas = _filtrar(data.licencas);
                final classV = ClassificadorVersoes(
                  data.pingPorMachine.values.map((p) => p.versao),
                );
                if (licencas.isEmpty) {
                  return const Center(child: Text('Nenhuma instalação.'));
                }
                return RefreshIndicator(
                  onRefresh: _recarregar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: licencas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final l = licencas[i];
                      final ultimoPing = data.pingPorMachine[l.machineId];
                      return _CartaoInstalacao(
                        licenca: l,
                        ultimoPing: ultimoPing,
                        estadoVersao: classV.estadoDe(ultimoPing?.versao),
                        onTap: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DetalheClienteScreen(nif: l.nif),
                                ),
                              )
                              .then((_) => _recarregar());
                        },
                      );
                    },
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
