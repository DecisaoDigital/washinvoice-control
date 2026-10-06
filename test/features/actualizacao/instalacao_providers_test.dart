import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/updates/instalador_de_update.dart';
import 'package:washinvoice_control/features/actualizacao/instalacao_providers.dart';

/// Nenhum ecrã do Android nesta sequência está preparado para landscape: nem
/// o pedido de autorização de fontes desconhecidas, nem o scan do Play
/// Protect, nem o instalador em si — os botões de confirmação ficam fora do
/// ecrã. É o mesmo bug que já mordeu o Fist (v0.1.6): forçar retrato antes
/// do primeiro pedido ao sistema evita repeti-lo aqui.
class _InstaladorFalso extends InstaladorDeUpdate {
  _InstaladorFalso({
    this.podeInstalarResultado = true,
    this.resultado = 'pediu_confirmacao',
  });

  final bool podeInstalarResultado;
  final String? resultado;
  final chamadas = <String>[];
  var pedidosDePermissao = 0;

  @override
  Future<bool> podeInstalar() async => podeInstalarResultado;

  @override
  Future<void> pedirPermissao() async => pedidosDePermissao++;

  @override
  Future<String?> instalar(String caminho) async {
    chamadas.add(caminho);
    return resultado;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rotacoes = <List<String>>[];

  setUp(() {
    rotacoes.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
          if (chamada.method == 'SystemChrome.setPreferredOrientations') {
            rotacoes.add(List<String>.from(chamada.arguments as List));
          }
          return null;
        });
  });

  ProviderContainer montar(WidgetTester tester, _InstaladorFalso instalador) {
    final container = ProviderContainer(
      overrides: [instaladorProvider.overrideWithValue(instalador)],
    );
    addTearDown(container.dispose);
    // Só para o `WidgetsBindingObserver` do controlador ter um binding activo
    // por trás — o próprio teste não olha para o que aqui se desenha.
    tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    return container;
  }

  testWidgets(
    'instalar força retrato antes de entregar o ficheiro ao Android',
    (tester) async {
      final instalador = _InstaladorFalso();
      final container = montar(tester, instalador);
      final notifier = container.read(estadoDoUpdateProvider.notifier);
      notifier.state = const EstadoDoUpdate(
        fase: FaseDoUpdate.pronta,
        caminho: '/tmp/control.apk',
      );

      await notifier.instalar();

      expect(instalador.chamadas, ['/tmp/control.apk']);
      expect(rotacoes, isNotEmpty);
      expect(rotacoes.last, ['DeviceOrientation.portraitUp']);
      expect(
        container.read(estadoDoUpdateProvider).fase,
        FaseDoUpdate.aguardaConfirmacao,
      );
    },
  );

  testWidgets(
    'voltar à app sem confirmar devolve a orientação e deixa tentar outra vez',
    (tester) async {
      final instalador = _InstaladorFalso();
      final container = montar(tester, instalador);
      final notifier = container.read(estadoDoUpdateProvider.notifier);
      notifier.state = const EstadoDoUpdate(
        fase: FaseDoUpdate.pronta,
        caminho: '/tmp/control.apk',
      );
      await notifier.instalar();
      expect(
        container.read(estadoDoUpdateProvider).fase,
        FaseDoUpdate.aguardaConfirmacao,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      final estado = container.read(estadoDoUpdateProvider);
      expect(estado.fase, FaseDoUpdate.pronta);
      expect(estado.caminho, '/tmp/control.apk');
      expect(rotacoes.last, isNot(['DeviceOrientation.portraitUp']));
    },
  );

  testWidgets('falha ao entregar o ficheiro também devolve a orientação', (
    tester,
  ) async {
    final instalador = _InstaladorFalso(resultado: null);
    final container = montar(tester, instalador);
    final notifier = container.read(estadoDoUpdateProvider.notifier);
    notifier.state = const EstadoDoUpdate(
      fase: FaseDoUpdate.pronta,
      caminho: '/tmp/control.apk',
    );

    await notifier.instalar();

    expect(container.read(estadoDoUpdateProvider).fase, FaseDoUpdate.falhou);
    expect(rotacoes.last, isNot(['DeviceOrientation.portraitUp']));
  });

  testWidgets(
    'sem autorização de fontes desconhecidas já força retrato antes de abrir as definições',
    (tester) async {
      final instalador = _InstaladorFalso(podeInstalarResultado: false);
      final container = montar(tester, instalador);
      final notifier = container.read(estadoDoUpdateProvider.notifier);
      notifier.state = const EstadoDoUpdate(
        fase: FaseDoUpdate.pronta,
        caminho: '/tmp/control.apk',
      );

      await notifier.instalar();

      // Pediu as definições, não chegou a entregar o ficheiro.
      expect(instalador.pedidosDePermissao, 1);
      expect(instalador.chamadas, isEmpty);
      expect(rotacoes.last, ['DeviceOrientation.portraitUp']);
      // A fase não muda enquanto se espera pelo regresso das definições.
      expect(
        container.read(estadoDoUpdateProvider).fase,
        FaseDoUpdate.pronta,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      expect(rotacoes.last, isNot(['DeviceOrientation.portraitUp']));
    },
  );
}
