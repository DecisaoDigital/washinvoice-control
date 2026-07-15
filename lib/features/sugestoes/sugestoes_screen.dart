import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/contexto_instalacoes.dart';
import '../../core/erros.dart';
import '../../core/widgets/widgets.dart';
import '../../models/sugestao.dart';
import '../../repositories/providers.dart';

class _SugestoesData {
  final List<Sugestao> porLer;
  final List<Sugestao> arquivo;
  final ContextoInstalacoes ctx;
  _SugestoesData({
    required this.porLer,
    required this.arquivo,
    required this.ctx,
  });

  int get marcadas => porLer.where((s) => s.marcada).length;
}

class SugestoesScreen extends ConsumerStatefulWidget {
  const SugestoesScreen({super.key});

  @override
  ConsumerState<SugestoesScreen> createState() => _SugestoesScreenState();
}

class _SugestoesScreenState extends ConsumerState<SugestoesScreen> {
  late Future<_SugestoesData> _future;
  bool _mostrarArquivo = false;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  Future<_SugestoesData> _carregar() async {
    final sugestoesRepo = ref.read(sugestoesRepoProvider);
    final clientesRepo = ref.read(clientesRepoProvider);
    final licencasRepo = ref.read(licencasRepoProvider);
    final pingsRepo = ref.read(pingsRepoProvider);

    final porLer = sugestoesRepo.listarPorLer();
    final arquivo = sugestoesRepo.listarArquivo();
    final clientes = clientesRepo.listar();
    final licencas = licencasRepo.listar();
    final pings = pingsRepo.ultimosPorInstalacao();
    await Future.wait([porLer, arquivo, clientes, licencas, pings]);

    return _SugestoesData(
      porLer: await porLer,
      arquivo: await arquivo,
      ctx: ContextoInstalacoes.build(
        clientes: await clientes,
        licencas: await licencas,
        pings: await pings,
      ),
    );
  }

  Future<void> _recarregar() async {
    setState(() => _future = _carregar());
    await _future;
  }

  Future<void> _toggleMarcar(Sugestao s) async {
    await ref.read(sugestoesRepoProvider).marcarMarcada(s.id, !s.marcada);
    await _recarregar();
  }

  Future<void> _arquivar(Sugestao s) async {
    await ref.read(sugestoesRepoProvider).arquivar(s.id);
    await _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<_SugestoesData>(
          future: _future,
          builder: (context, snapshot) {
            final d = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sugestões', style: TextStyle(fontSize: 18)),
                if (d != null)
                  Text(
                    '${d.porLer.length} por ler · ${d.marcadas} marcadas',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      body: FutureBuilder<_SugestoesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErroView(erro: snapshot.error!, onRetry: _recarregar);
          }
          final data = snapshot.data!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _Toggle(
                  porLer: data.porLer.length,
                  arquivo: data.arquivo.length,
                  mostrarArquivo: _mostrarArquivo,
                  onChanged: (v) => setState(() => _mostrarArquivo = v),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _recarregar,
                  child: _mostrarArquivo
                      ? _ListaArquivo(data)
                      : _ListaPorLer(
                          data,
                          onMarcar: _toggleMarcar,
                          onArquivar: _arquivar,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final int porLer;
  final int arquivo;
  final bool mostrarArquivo;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.porLer,
    required this.arquivo,
    required this.mostrarArquivo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.fundo,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: AppColors.borda),
      ),
      child: Row(
        children: [
          _seg('Por ler ($porLer)', !mostrarArquivo, () => onChanged(false)),
          _seg('Arquivo ($arquivo)', mostrarArquivo, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _seg(String label, bool activo, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: activo ? AppColors.azul900 : Colors.transparent,
        borderRadius: AppRadius.pillAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: activo ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListaPorLer extends StatelessWidget {
  final _SugestoesData data;
  final Future<void> Function(Sugestao) onMarcar;
  final Future<void> Function(Sugestao) onArquivar;
  const _ListaPorLer(this.data,
      {required this.onMarcar, required this.onArquivar});

  @override
  Widget build(BuildContext context) {
    if (data.porLer.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          WiEmptyState(
            icone: Icons.mark_email_read_outlined,
            titulo: 'Tudo lido',
            mensagem: 'Não há sugestões por ler.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      itemCount: data.porLer.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final s = data.porLer[i];
        return _CardPorLer(
          sugestao: s,
          nome: data.ctx.nomeDe(machineId: s.machineId ?? '', nif: s.nif),
          onMarcar: () => onMarcar(s),
          onArquivar: () => onArquivar(s),
        );
      },
    );
  }
}

class _CardPorLer extends StatelessWidget {
  final Sugestao sugestao;
  final String nome;
  final VoidCallback onMarcar;
  final VoidCallback onArquivar;

  const _CardPorLer({
    required this.sugestao,
    required this.nome,
    required this.onMarcar,
    required this.onArquivar,
  });

  @override
  Widget build(BuildContext context) {
    final tempo = timeago.format(sugestao.criadoEm, locale: 'pt');
    return WiCardDestaque(
      cor: AppColors.roxo500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: AppColors.roxo700, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(nome, style: AppText.bodyStrong)),
              Text('há $tempo', style: AppText.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            sugestao.texto,
            style: AppText.body.copyWith(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMarcar,
                  icon: Icon(
                    sugestao.marcada ? Icons.star : Icons.star_border,
                    size: 18,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.laranja700,
                    side: const BorderSide(color: AppColors.laranja700),
                  ),
                  label: Text(sugestao.marcada ? 'Marcada' : 'Marcar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onArquivar,
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.textTertiary),
                  ),
                  label: const Text('Arquivar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListaArquivo extends StatelessWidget {
  final _SugestoesData data;
  const _ListaArquivo(this.data);

  @override
  Widget build(BuildContext context) {
    if (data.arquivo.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          WiEmptyState(
            icone: Icons.inventory_2_outlined,
            titulo: 'Arquivo vazio',
            mensagem: 'Ainda não arquivaste sugestões.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      itemCount: data.arquivo.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final s = data.arquivo[i];
        return _CardArquivo(
          sugestao: s,
          nome: data.ctx.nomeDe(machineId: s.machineId ?? '', nif: s.nif),
        );
      },
    );
  }
}

class _CardArquivo extends StatelessWidget {
  final Sugestao sugestao;
  final String nome;
  const _CardArquivo({required this.sugestao, required this.nome});

  @override
  Widget build(BuildContext context) {
    return WiCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      onTap: () => _abrir(context),
      child: Row(
        children: [
          Icon(
            sugestao.marcada ? Icons.star : Icons.archive_outlined,
            size: 20,
            color: sugestao.marcada
                ? AppColors.laranja700
                : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: AppText.bodyStrong, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(sugestao.texto,
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

  void _abrir(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(nome, style: AppText.h2)),
                Text(timeago.format(sugestao.criadoEm, locale: 'pt'),
                    style: AppText.caption),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(sugestao.texto,
                style: AppText.body.copyWith(height: 1.5)),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
