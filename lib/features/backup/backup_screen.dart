import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/contexto_instalacoes.dart';
import '../../core/csv.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../models/cliente.dart';
import '../../models/licenca.dart';
import '../../models/pedido_ajuda.dart';
import '../../models/sugestao.dart';
import '../../repositories/providers.dart';
import '../pedidos_ajuda/pedidos_ajuda_screen.dart' show formatarDuracao;

class _BackupData {
  final List<Cliente> clientes;
  final List<Licenca> licencas;
  final List<PedidoAjuda> pedidos;
  final List<Sugestao> sugestoes;
  final ContextoInstalacoes ctx;
  _BackupData(this.clientes, this.licencas, this.pedidos, this.sugestoes,
      this.ctx);
}

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  late Future<_BackupData> _future;
  bool _aExportar = false;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<_BackupData> _carregar() async {
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
    return _BackupData(
      clientes,
      licencas,
      [...await abertosF, ...await histF],
      [...await porLerF, ...await arquivoF],
      ContextoInstalacoes.build(
          clientes: clientes, licencas: licencas, pings: pings),
    );
  }

  // ── Geração dos CSV ────────────────────────────────────────────────────────

  String _csvClientes(_BackupData d) => Csv.documento(
        ['id', 'nif', 'nome', 'email', 'telemovel', 'localidade', 'notas',
            'criado_em'],
        [
          for (final c in d.clientes)
            [c.id, c.nif, c.nome, c.email, c.telemovel, c.localidade, c.notas,
                c.criadoEm.toIso8601String()],
        ],
      );

  String _csvLicencas(_BackupData d) => Csv.documento(
        ['id', 'cliente_id', 'machine_id', 'nif', 'nome', 'plano', 'validade',
            'activa', 'oferta', 'serie', 'criado_em'],
        [
          for (final l in d.licencas)
            [l.id, l.clienteId, l.machineId, l.nif, l.nome, l.plano,
                Dates.data(l.validade), l.activa, l.oferta, l.serie,
                l.criadoEm.toIso8601String()],
        ],
      );

  String _csvPedidos(_BackupData d) => Csv.documento(
        ['id', 'machine_id', 'nif', 'cliente', 'criado_em', 'resolvido_em',
            'duracao', 'notas'],
        [
          for (final p in d.pedidos)
            [
              p.id, p.machineId, p.nif,
              d.ctx.nomeDe(machineId: p.machineId, nif: p.nif),
              p.criadoEm.toIso8601String(),
              p.resolvidoEm?.toIso8601String() ?? '',
              formatarDuracao(p.duracao),
              p.notas,
            ],
        ],
      );

  String _csvSugestoes(_BackupData d) => Csv.documento(
        ['id', 'machine_id', 'nif', 'cliente', 'texto', 'criado_em', 'lida',
            'marcada', 'arquivada'],
        [
          for (final s in d.sugestoes)
            [
              s.id, s.machineId, s.nif,
              d.ctx.nomeDe(machineId: s.machineId ?? '', nif: s.nif),
              s.texto, s.criadoEm.toIso8601String(), s.lida, s.marcada,
              s.arquivada,
            ],
        ],
      );

  // ── Partilha ────────────────────────────────────────────────────────────────

  Future<void> _partilhar(String nome, Uint8List bytes, String mime) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$nome');
    await f.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(f.path, mimeType: mime)]);
  }

  Future<void> _exportar(String nome, String csv) async {
    setState(() => _aExportar = true);
    try {
      await _partilhar(nome, Csv.bytes(csv), 'text/csv');
    } catch (e, st) {
      mostrarErro(e, stack: st);
    } finally {
      if (mounted) setState(() => _aExportar = false);
    }
  }

  Future<void> _exportarTudo(_BackupData d) async {
    setState(() => _aExportar = true);
    try {
      final archive = Archive();
      void add(String nome, String csv) {
        final b = Csv.bytes(csv);
        archive.addFile(ArchiveFile(nome, b.length, b));
      }

      add('clientes.csv', _csvClientes(d));
      add('licencas.csv', _csvLicencas(d));
      add('pedidos_ajuda.csv', _csvPedidos(d));
      add('sugestoes.csv', _csvSugestoes(d));
      final zip = ZipEncoder().encode(archive);
      if (zip == null) throw Exception('Falha a gerar o ZIP.');
      await _partilhar('washinvoice_backup.zip',
          Uint8List.fromList(zip), 'application/zip');
    } catch (e, st) {
      mostrarErro(e, stack: st);
    } finally {
      if (mounted) setState(() => _aExportar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar dados')),
      body: FutureBuilder<_BackupData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErroView(
                erro: snapshot.error!,
                onRetry: () => setState(() => _future = _carregar()));
          }
          final d = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Gera um ficheiro e abre a partilha — escolhe onde guardar '
                '(Google Drive, email para ti, etc.). CSV em UTF-8 (abre no Excel).',
                style: AppText.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              _botao(Icons.people_outline, 'Exportar clientes (${d.clientes.length})',
                  () => _exportar('clientes.csv', _csvClientes(d))),
              _botao(Icons.workspace_premium,
                  'Exportar licenças (${d.licencas.length})',
                  () => _exportar('licencas.csv', _csvLicencas(d))),
              _botao(Icons.help_outline,
                  'Exportar pedidos de ajuda (${d.pedidos.length})',
                  () => _exportar('pedidos_ajuda.csv', _csvPedidos(d))),
              _botao(Icons.lightbulb_outline,
                  'Exportar sugestões (${d.sugestoes.length})',
                  () => _exportar('sugestoes.csv', _csvSugestoes(d))),
              const Divider(height: AppSpacing.xxl),
              _botao(Icons.folder_zip_outlined, 'Exportar tudo (ZIP)',
                  () => _exportarTudo(d), destaque: true),
            ],
          );
        },
      ),
    );
  }

  Widget _botao(IconData icone, String label, VoidCallback onPressed,
      {bool destaque = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: destaque
            ? FilledButton.icon(
                icon: Icon(icone),
                label: Text(label),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.azul700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _aExportar ? null : onPressed,
              )
            : OutlinedButton.icon(
                icon: Icon(icone),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.azul700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: _aExportar ? null : onPressed,
              ),
      ),
    );
  }
}
