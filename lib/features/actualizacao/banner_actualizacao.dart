import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/updates/instalador_de_update.dart';
import '../../models/actualizacao_info.dart';
import '../../repositories/providers.dart';
import 'instalacao_providers.dart';

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
///
/// O botão muda com a fase da instalação (`estadoDoUpdateProvider`): a
/// descarga acontece sozinha em segundo plano (quando há `sha256` publicado)
/// e o admin só decide **quando** instalar. Sem hash publicado, ou se a
/// instalação falhar, o caminho é sempre o antigo — pelo browser.
class BannerActualizacao extends ConsumerWidget {
  final DescarregarUrl descarregar;

  const BannerActualizacao({super.key, this.descarregar = _descarregarPadrao});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(actualizacaoDisponivelProvider);
    if (info == null) return const SizedBox.shrink();
    final instalacao = ref.watch(estadoDoUpdateProvider);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(obrigatoria ? Icons.warning_amber : Icons.info_outline,
                      color: corTexto, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _titulo(info, instalacao),
                      style: TextStyle(
                        color: corTexto,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (temNotas && instalacao.fase == FaseDoUpdate.disponivel)
                    TextButton(
                      onPressed: () => _mostrarNotas(context, info),
                      child: const Text('Ver o que mudou'),
                    ),
                  _AccaoActualizacao(info: info, instalacao: instalacao, descarregar: descarregar),
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
              if (instalacao.fase == FaseDoUpdate.aDescarregar) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: instalacao.progresso == 0 ? null : instalacao.progresso,
                  color: corTexto,
                ),
              ] else if (instalacao.erro != null) ...[
                const SizedBox(height: 4),
                Text(instalacao.erro!, style: TextStyle(color: corTexto)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _titulo(ActualizacaoInfo info, EstadoDoUpdate instalacao) =>
      switch (instalacao.fase) {
        FaseDoUpdate.aDescarregar =>
          'A descarregar a versão ${info.versaoActual}…',
        FaseDoUpdate.pronta => 'Versão ${info.versaoActual} pronta a instalar',
        FaseDoUpdate.aInstalar => 'A instalar…',
        FaseDoUpdate.aguardaConfirmacao => 'Confirma no ecrã do Android',
        FaseDoUpdate.falhou => 'Não foi possível actualizar sozinho',
        FaseDoUpdate.disponivel => 'Nova versão ${info.versaoActual} disponível',
      };

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

/// O botão de acção do banner, dependente da fase da instalação.
///
/// Sem `sha256` publicado a fase fica sempre presa em [FaseDoUpdate.disponivel]
/// (o [InstalacaoController] recusa-se a descarregar sem hash — ver
/// `instalador_de_update.dart`), por isso este ramo continua a abrir o
/// browser tal como sempre abriu: nenhum comportamento antigo muda quando o
/// catálogo não publica hash.
class _AccaoActualizacao extends ConsumerWidget {
  const _AccaoActualizacao({
    required this.info,
    required this.instalacao,
    required this.descarregar,
  });

  final ActualizacaoInfo info;
  final EstadoDoUpdate instalacao;
  final DescarregarUrl descarregar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(estadoDoUpdateProvider.notifier);

    switch (instalacao.fase) {
      case FaseDoUpdate.aDescarregar:
      case FaseDoUpdate.aInstalar:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );

      case FaseDoUpdate.pronta:
        return ElevatedButton(
          onPressed: controller.instalar,
          child: const Text('Instalar'),
        );

      case FaseDoUpdate.aguardaConfirmacao:
        return const SizedBox.shrink();

      case FaseDoUpdate.falhou:
        // Sempre uma saída pelo browser: um instalador que falha não pode
        // deixar o admin sem forma de actualizar.
        return ElevatedButton(
          onPressed: () => descarregar(Uri.parse(info.urlDownload)),
          child: const Text('Descarregar'),
        );

      case FaseDoUpdate.disponivel:
        if ((info.sha256 ?? '').isEmpty) {
          return ElevatedButton(
            onPressed: () => descarregar(Uri.parse(info.urlDownload)),
            child: const Text('Descarregar'),
          );
        }
        return ElevatedButton(
          onPressed: () => controller.descarregarAgora(info),
          child: const Text('Actualizar'),
        );
    }
  }
}

/// Modal bloqueante para actualização **obrigatória** (bug fiscal/segurança
/// crítico). Não se pode fechar sem actualizar: sem X, sem barrier, sem back.
/// O [HomeShell] chama isto quando `actualizacaoDisponivelProvider` passa a ter
/// uma actualização com `obrigatoria == true`.
///
/// Mesmo botão de acção do banner ([_AccaoActualizacao]), por isso segue a
/// fase de `estadoDoUpdateProvider`: sem hash publicado (ou se a instalação
/// falhar) continua "Descarregar" pelo browser; com hash, descarrega e instala
/// sem sair daqui.
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
          Consumer(
            builder: (context, ref, _) => _AccaoActualizacao(
              info: info,
              instalacao: ref.watch(estadoDoUpdateProvider),
              descarregar: descarregar,
            ),
          ),
        ],
      ),
    ),
  );
}
