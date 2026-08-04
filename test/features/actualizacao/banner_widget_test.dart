import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/updates/instalador_de_update.dart';
import 'package:washinvoice_control/features/actualizacao/banner_actualizacao.dart';
import 'package:washinvoice_control/features/actualizacao/instalacao_providers.dart';
import 'package:washinvoice_control/models/actualizacao_info.dart';
import 'package:washinvoice_control/repositories/providers.dart';

ActualizacaoInfo _info({required bool obrigatoria, String? sha256}) =>
    ActualizacaoInfo(
      versaoActual: '1.7.1',
      buildNumber: 25,
      urlDownload: 'https://exemplo/apk',
      obrigatoria: obrigatoria,
      sha256: sha256,
    );

/// Nunca chega a descarregar nada a sério: só regista o que lhe pediram, para
/// os testes do banner confirmarem a intenção sem sair à rede.
class _InstaladorFalso extends InstaladorDeUpdate {
  final pedidosDeDownload = <ActualizacaoInfo>[];

  @override
  Future<String?> descarregar(
    ActualizacaoInfo info, {
    void Function(double)? aoProgredir,
  }) async {
    pedidosDeDownload.add(info);
    return null;
  }
}

Future<ProviderContainer> _montar(
  WidgetTester tester, {
  ActualizacaoInfo? info,
  DescarregarUrl? descarregar,
  InstaladorDeUpdate? instalador,
  EstadoDoUpdate? estadoInstalacao,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (instalador != null) instaladorProvider.overrideWithValue(instalador),
    ],
  );
  addTearDown(container.dispose);
  if (info != null) {
    container.read(actualizacaoDisponivelProvider.notifier).state = info;
  }
  if (estadoInstalacao != null) {
    container.read(estadoDoUpdateProvider.notifier).state = estadoInstalacao;
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: BannerActualizacao(
            descarregar: descarregar ?? (_) async => true,
          ),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('sem actualização → banner não aparece', (tester) async {
    await _montar(tester);
    expect(find.text('Descarregar'), findsNothing);
    expect(find.textContaining('Nova versão'), findsNothing);
  });

  testWidgets('não obrigatória → banner com info e X', (tester) async {
    await _montar(tester, info: _info(obrigatoria: false));
    expect(find.textContaining('Nova versão 1.7.1'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.text('Descarregar'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget); // dispensável
  });

  testWidgets('obrigatória → banner vermelho sem X', (tester) async {
    await _montar(tester, info: _info(obrigatoria: true));
    expect(find.textContaining('Nova versão 1.7.1'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.text('Descarregar'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing); // não se pode dispensar
  });

  testWidgets('carregar em Descarregar chama o launcher com o URL',
      (tester) async {
    Uri? aberto;
    await _montar(
      tester,
      info: _info(obrigatoria: false),
      descarregar: (url) async {
        aberto = url;
        return true;
      },
    );

    await tester.tap(find.text('Descarregar'));
    await tester.pump();

    expect(aberto, Uri.parse('https://exemplo/apk'));
  });

  testWidgets('X dispensa o banner (limpa o provider)', (tester) async {
    final container =
        await _montar(tester, info: _info(obrigatoria: false));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(container.read(actualizacaoDisponivelProvider), isNull);
    expect(find.text('Descarregar'), findsNothing);
  });

  group('com sha256 publicado', () {
    testWidgets('disponível → botão "Actualizar" (não "Descarregar")',
        (tester) async {
      await _montar(
        tester,
        info: _info(obrigatoria: false, sha256: 'abc123'),
      );
      expect(find.text('Actualizar'), findsOneWidget);
      expect(find.text('Descarregar'), findsNothing);
    });

    testWidgets('carregar em Actualizar arranca a descarga (sem abrir o browser)',
        (tester) async {
      final instalador = _InstaladorFalso();
      Uri? aberto;
      await _montar(
        tester,
        info: _info(obrigatoria: false, sha256: 'abc123'),
        instalador: instalador,
        descarregar: (url) async {
          aberto = url;
          return true;
        },
      );

      await tester.tap(find.text('Actualizar'));
      await tester.pump();

      expect(instalador.pedidosDeDownload, hasLength(1));
      expect(aberto, isNull);
    });

    testWidgets('a descarregar → progresso visível, sem botão de acção',
        (tester) async {
      await _montar(
        tester,
        info: _info(obrigatoria: false, sha256: 'abc123'),
        estadoInstalacao: const EstadoDoUpdate(
          fase: FaseDoUpdate.aDescarregar,
          progresso: 0.4,
        ),
      );

      expect(find.textContaining('A descarregar a versão 1.7.1'),
          findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Actualizar'), findsNothing);
      expect(find.text('Instalar'), findsNothing);
    });

    testWidgets('pronta → botão "Instalar" chama o controlador',
        (tester) async {
      final rotacoes = <List<String>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
            if (chamada.method == 'SystemChrome.setPreferredOrientations') {
              rotacoes.add(List<String>.from(chamada.arguments as List));
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await _montar(
        tester,
        info: _info(obrigatoria: false, sha256: 'abc123'),
        estadoInstalacao: const EstadoDoUpdate(
          fase: FaseDoUpdate.pronta,
          caminho: '/tmp/control.apk',
        ),
      );

      expect(find.text('Instalar'), findsOneWidget);
      await tester.tap(find.text('Instalar'));
      await tester.pump();

      // Sem canal nativo de instalação (ambiente de teste), a sequência fica
      // presa à espera de autorização — mas o toque chegou mesmo ao
      // controlador: forçou retrato antes de sequer perguntar, tal como
      // `instalacao_providers_test.dart` confirma em isolamento.
      expect(rotacoes, isNotEmpty);
      expect(rotacoes.last, ['DeviceOrientation.portraitUp']);
    });

    testWidgets('falhou → volta a oferecer "Descarregar" pelo browser',
        (tester) async {
      Uri? aberto;
      await _montar(
        tester,
        info: _info(obrigatoria: false, sha256: 'abc123'),
        estadoInstalacao: const EstadoDoUpdate(
          fase: FaseDoUpdate.falhou,
          erro: 'A instalação não arrancou.',
        ),
        descarregar: (url) async {
          aberto = url;
          return true;
        },
      );

      expect(find.text('A instalação não arrancou.'), findsOneWidget);
      expect(find.text('Descarregar'), findsOneWidget);
      await tester.tap(find.text('Descarregar'));
      await tester.pump();

      expect(aberto, Uri.parse('https://exemplo/apk'));
    });
  });
}
