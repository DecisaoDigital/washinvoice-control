import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../models/actualizacao_info.dart';
import '../../repositories/providers.dart';

/// Abre um URL. Injectável para os testes de widget não saírem à rede/browser.
typedef DescarregarUrl = Future<bool> Function(Uri url);

Future<bool> _descarregarPadrao(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Banner persistente no topo do Control quando há actualização não obrigatória.
///
/// - Sem actualização, ou actualização **obrigatória**, não desenha nada aqui:
///   o obrigatório é tratado pelo modal bloqueante ([mostrarModalObrigatorio]),
///   não por um banner que se possa ignorar.
///
/// (Renderiza também o caso obrigatório em vermelho-sem-X para quem o queira
/// mostrar inline, mas por omissão o [HomeShell] usa o modal.)
class BannerActualizacao extends ConsumerWidget {
  final DescarregarUrl descarregar;

  const BannerActualizacao({super.key, this.descarregar = _descarregarPadrao});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(actualizacaoDisponivelProvider);
    if (info == null) return const SizedBox.shrink();

    final obrigatoria = info.obrigatoria;
    final corTexto = obrigatoria ? AppColors.vermelho : AppColors.laranja700;
    final corFundo = obrigatoria ? AppColors.vermelho100 : AppColors.laranja100;
    final temNotas =
        info.notasLancamento != null && info.notasLancamento!.trim().isNotEmpty;

    return SafeArea(
      bottom: false,
      child: Material(
        color: corFundo,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(obrigatoria ? Icons.warning_amber : Icons.info_outline,
                  color: corTexto, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nova versão ${info.versaoActual} disponível',
                  style: TextStyle(
                    color: corTexto,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (temNotas)
                TextButton(
                  onPressed: () => _mostrarNotas(context, info),
                  child: const Text('Ver o que mudou'),
                ),
              ElevatedButton(
                onPressed: () => descarregar(Uri.parse(info.urlDownload)),
                child: const Text('Descarregar'),
              ),
              if (!obrigatoria)
                IconButton(
                  icon: const Icon(Icons.close),
                  color: corTexto,
                  tooltip: 'Dispensar até ao próximo arranque',
                  onPressed: () => ref
                      .read(actualizacaoDisponivelProvider.notifier)
                      .state = null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarNotas(BuildContext context, ActualizacaoInfo info) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Novidades da versão ${info.versaoActual}'),
        content: SingleChildScrollView(
          child: Text(info.notasLancamento ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

/// Modal bloqueante para actualização **obrigatória** (bug fiscal/segurança
/// crítico). Não se pode fechar sem descarregar: sem X, sem barrier, sem back.
/// O [HomeShell] chama isto quando `actualizacaoDisponivelProvider` passa a ter
/// uma actualização com `obrigatoria == true`.
Future<void> mostrarModalObrigatorio(
  BuildContext context,
  ActualizacaoInfo info, {
  DescarregarUrl descarregar = _descarregarPadrao,
}) {
  final temNotas =
      info.notasLancamento != null && info.notasLancamento!.trim().isNotEmpty;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.warning_amber, color: AppColors.vermelho),
        title: Text('Actualização obrigatória — versão ${info.versaoActual}'),
        content: SingleChildScrollView(
          child: Text(
            temNotas
                ? info.notasLancamento!
                : 'Esta actualização corrige um problema crítico e é '
                    'obrigatória. Descarrega a nova versão para continuar.',
          ),
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Descarregar'),
            onPressed: () => descarregar(Uri.parse(info.urlDownload)),
          ),
        ],
      ),
    ),
  );
}
