import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/updates/instalador_de_update.dart';
import 'package:washinvoice_control/models/actualizacao_info.dart';

/// O instalador só corre sobre um ficheiro que confere com o hash publicado.
///
/// O `url_download` vem de uma coluna editável em `versoes_apps`. Sem esta
/// verificação, uma linha errada faria a app instalar outra coisa qualquer
/// com a confiança de ser uma actualização legítima.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory pasta;

  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('control-instalador');
  });
  tearDown(() async {
    if (await pasta.exists()) await pasta.delete(recursive: true);
  });

  ActualizacaoInfo info({String? sha, String url = 'https://exemplo/c.apk'}) =>
      ActualizacaoInfo(
        versaoActual: '1.8.6',
        buildNumber: 31,
        urlDownload: url,
        obrigatoria: false,
        sha256: sha,
      );

  test('versão sem hash publicado não é descarregada', () async {
    // Recusar é a decisão certa: sem forma de verificar, o caminho antigo
    // pelo browser é mais honesto do que instalar às cegas.
    final caminho = await InstaladorDeUpdate().descarregar(info());

    expect(caminho, isNull);
  });

  test('hash vazio conta como não publicado', () async {
    expect(await InstaladorDeUpdate().descarregar(info(sha: '   ')), isNull);
  });

  test('o modelo transporta o hash de ida e volta', () {
    final volta = ActualizacaoInfo.fromJson({
      'versao_actual': '1.8.6',
      'build_number': 31,
      'url_download': 'https://exemplo/c.apk',
      'obrigatoria': false,
      'sha256': 'abc123',
    });

    expect(volta.sha256, 'abc123');
  });

  test(
    'sem canal nativo, instalar falha em silêncio em vez de rebentar',
    () async {
      // Windows e testes não têm o canal. A app não pode estoirar por isso.
      expect(await InstaladorDeUpdate().podeInstalar(), isFalse);
      expect(await InstaladorDeUpdate().instalar('/nao/existe.apk'), isNull);
    },
  );
}
