import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/updates/instalador_de_update.dart';
import '../../models/actualizacao_info.dart';
import '../../repositories/providers.dart';

final instaladorProvider = Provider<InstaladorDeUpdate>(
  (_) => InstaladorDeUpdate(),
);

/// Trata da actualização do princípio ao fim: descarrega em segundo plano,
/// verifica e instala.
///
/// O download acontece sozinho, sem obrigar a sair da app — é a instalação
/// que não pode ser totalmente silenciosa: o Android só a dispensa de
/// confirmação a partir do 12, e mesmo aí só quando foi o próprio Control a
/// instalar a versão anterior. Da segunda actualização em diante deixa de
/// haver toque nenhum.
final estadoDoUpdateProvider =
    NotifierProvider<InstalacaoController, EstadoDoUpdate>(
      InstalacaoController.new,
    );

class InstalacaoController extends Notifier<EstadoDoUpdate> {
  bool _vivo = true;

  /// Verdadeiro enquanto o retrato estiver imposto por causa desta sequência
  /// (pedido de permissão + instalação). Existe para o regresso à app saber
  /// se há alguma coisa para largar — sem isto, um regresso normal (o admin
  /// só alternou de app) largaria uma sobreposição que nunca pediu.
  bool _aSegurarRetrato = false;
  _ObservadorDeRegressoDoInstalador? _observador;

  @override
  EstadoDoUpdate build() {
    // Uma versão nova a aparecer arranca a descarga por si. Só isso, e só se
    // o ficheiro puder ser verificado.
    ref.listen<ActualizacaoInfo?>(actualizacaoDisponivelProvider, (
      anterior,
      actual,
    ) {
      if (actual == null) return;
      if (anterior?.buildNumber == actual.buildNumber) return;
      if ((actual.sha256 ?? '').isEmpty) return;
      unawaited(descarregar(actual));
    });
    _observador = _ObservadorDeRegressoDoInstalador(() {
      if (!_vivo || !_aSegurarRetrato) return;
      // Voltar à app enquanto se segurava o retrato só acontece quando o
      // admin recusou a permissão, saiu do instalador sem decidir, ou o
      // Play Protect terminou o scan sem instalar nada — uma instalação que
      // corre até ao fim mata o processo.
      unawaited(_libertarRetrato());
      if (state.fase == FaseDoUpdate.aInstalar ||
          state.fase == FaseDoUpdate.aguardaConfirmacao) {
        state = EstadoDoUpdate(
          fase: FaseDoUpdate.pronta,
          caminho: state.caminho,
        );
      }
    });
    WidgetsBinding.instance.addObserver(_observador!);
    ref.onDispose(() {
      _vivo = false;
      if (_observador != null) {
        WidgetsBinding.instance.removeObserver(_observador!);
      }
    });
    return const EstadoDoUpdate(fase: FaseDoUpdate.disponivel);
  }

  Future<void> descarregar(ActualizacaoInfo info) async {
    if (state.fase == FaseDoUpdate.aDescarregar) return;
    // Só em Wi-Fi por defeito: um APK pode ir a dezenas de MB, e gastá-los
    // nos dados móveis do admin sem avisar é abusar da confiança. Quem
    // quiser força pelo botão.
    if (!await _emWifi()) {
      debugPrint('[Instalador] sem Wi-Fi — descarga adiada');
      return;
    }
    await _descarregar(info);
  }

  /// Descarrega mesmo sem Wi-Fi, porque foi o admin a pedir.
  Future<void> descarregarAgora(ActualizacaoInfo info) => _descarregar(info);

  Future<void> _descarregar(ActualizacaoInfo info) async {
    state = const EstadoDoUpdate(fase: FaseDoUpdate.aDescarregar);
    final caminho = await ref
        .read(instaladorProvider)
        .descarregar(
          info,
          aoProgredir: (p) {
            if (state.fase == FaseDoUpdate.aDescarregar) {
              state = state.com(progresso: p);
            }
          },
        );
    if (caminho == null) {
      state = const EstadoDoUpdate(
        fase: FaseDoUpdate.falhou,
        erro: 'Não foi possível descarregar a actualização.',
      );
      return;
    }
    state = EstadoDoUpdate(fase: FaseDoUpdate.pronta, caminho: caminho);
  }

  /// Entrega ao Android. A app pode ser morta a meio disto — é o que
  /// acontece quando a instalação corre bem, e não é erro.
  Future<void> instalar() async {
    final caminho = state.caminho;
    if (caminho == null) return;
    final instalador = ref.read(instaladorProvider);

    // Nenhum ecrã do Android nesta sequência está preparado para landscape:
    // nem o pedido de autorização de fontes desconhecidas, nem o scan do
    // Play Protect, nem o instalador em si — os botões de confirmação ficam
    // fora do ecrã. Força-se retrato já aqui, antes do primeiro pedido ao
    // sistema, e só se larga quando a sequência termina, com sucesso ou sem
    // ele (ver `_libertarRetrato` e o observador de regresso à app, em
    // `build`).
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _aSegurarRetrato = true;

    if (!await instalador.podeInstalar()) {
      // O Android exige autorização explícita para esta app instalar
      // pacotes. Abrem-se as definições; o admin volta (o observador trata
      // do retrato) e carrega outra vez.
      await instalador.pedirPermissao();
      return;
    }

    state = state.com(fase: FaseDoUpdate.aInstalar);
    final desfecho = await instalador.instalar(caminho);
    if (desfecho == null) {
      await _libertarRetrato();
      state = state.com(
        fase: FaseDoUpdate.falhou,
        erro: 'A instalação não arrancou.',
      );
      return;
    }
    if (desfecho == 'pediu_confirmacao') {
      state = state.com(fase: FaseDoUpdate.aguardaConfirmacao);
    }
  }

  Future<void> _libertarRetrato() async {
    if (!_aSegurarRetrato) return;
    _aSegurarRetrato = false;
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  /// Wi-Fi é a única ligação que se assume gratuita. Sem forma de saber
  /// (Windows, testes), assume-se que sim — nesses casos não há plafond a
  /// gastar.
  Future<bool> _emWifi() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );
      if (interfaces.isEmpty) return false;
      // Em Android as interfaces de dados móveis chamam-se rmnet*/ccmni*; as
      // de Wi-Fi, wlan*. Não é infalível, mas erra para o lado seguro: se
      // não reconhecer Wi-Fi, não descarrega sozinho.
      return interfaces.any((i) => i.name.startsWith('wlan'));
    } catch (erro) {
      debugPrint('[Instalador] não consegui ver a rede: $erro');
      return false;
    }
  }
}

/// Observador mínimo do ciclo de vida, só para saber quando se volta do
/// instalador do Android sem ter instalado nada.
class _ObservadorDeRegressoDoInstalador extends WidgetsBindingObserver {
  _ObservadorDeRegressoDoInstalador(this.aoRegressar);
  final VoidCallback aoRegressar;

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) aoRegressar();
  }
}
