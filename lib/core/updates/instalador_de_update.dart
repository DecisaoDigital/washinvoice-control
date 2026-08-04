import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/actualizacao_info.dart';

/// Em que ponto está a actualização.
enum FaseDoUpdate {
  /// Há versão nova e ainda não se mexeu nela.
  disponivel,
  aDescarregar,

  /// Ficheiro em disco e verificado. Pronto a instalar quando o admin quiser.
  pronta,
  aInstalar,

  /// O Android pediu confirmação — a app não pode fazer mais nada por si.
  aguardaConfirmacao,
  falhou,
}

class EstadoDoUpdate {
  const EstadoDoUpdate({
    required this.fase,
    this.progresso = 0,
    this.caminho,
    this.erro,
  });

  final FaseDoUpdate fase;

  /// 0 a 1. Só faz sentido em [FaseDoUpdate.aDescarregar].
  final double progresso;
  final String? caminho;
  final String? erro;

  EstadoDoUpdate com({
    FaseDoUpdate? fase,
    double? progresso,
    String? caminho,
    String? erro,
  }) => EstadoDoUpdate(
    fase: fase ?? this.fase,
    progresso: progresso ?? this.progresso,
    caminho: caminho ?? this.caminho,
    erro: erro,
  );
}

/// Descarrega e instala a nova versão sem sair da app.
///
/// Antes disto o botão abria o browser e o admin percorria notificação, aviso
/// de ficheiro perigoso, ecrã de instalação e "Abrir".
///
/// **A verificação do SHA-256 não é opcional.** O `urlDownload` vem de uma
/// coluna editável em `versoes_apps`; sem confirmar o ficheiro, uma linha
/// errada faria a app instalar outra coisa qualquer com a confiança de ser
/// uma actualização legítima. Sem hash publicado, o instalador recusa-se a
/// correr e o caminho fica o antigo, pelo browser.
class InstaladorDeUpdate {
  InstaladorDeUpdate({MethodChannel? canal, HttpClient? http})
    : _canal = canal ?? const MethodChannel('control/instalador'),
      _http = http;

  final MethodChannel _canal;
  final HttpClient? _http;

  Future<bool> podeInstalar() async {
    try {
      return await _canal.invokeMethod<bool>('podeInstalar') ?? false;
    } on PlatformException catch (e) {
      debugPrint('[Instalador] podeInstalar falhou: ${e.code}');
      return false;
    } on MissingPluginException {
      // Windows, testes, qualquer sítio sem o canal nativo.
      return false;
    }
  }

  Future<void> pedirPermissao() async {
    try {
      await _canal.invokeMethod<void>('pedirPermissao');
    } on PlatformException catch (e) {
      debugPrint('[Instalador] pedirPermissao falhou: ${e.code}');
    } on MissingPluginException {
      // Sem canal nativo não há nada a pedir.
    }
  }

  /// Descarrega o APK e confirma-o contra o hash publicado.
  ///
  /// Devolve o caminho do ficheiro, ou `null` se falhou — e nesse caso apaga
  /// o que ficou a meio, para não deixar dezenas de MB de lixo no telemóvel
  /// nem um ficheiro truncado que uma tentativa seguinte confundisse com bom.
  Future<String?> descarregar(
    ActualizacaoInfo info, {
    void Function(double)? aoProgredir,
  }) async {
    if ((info.sha256 ?? '').isEmpty) {
      debugPrint('[Instalador] versão sem sha256 publicado — não instalo');
      return null;
    }
    File? destino;
    try {
      final pasta = await getApplicationSupportDirectory();
      destino = File('${pasta.path}/control-${info.buildNumber}.apk');
      if (await destino.exists()) {
        // Já cá está de uma tentativa anterior: se o hash bater, poupa-se o
        // download todo.
        if (await _confere(destino, info.sha256!)) return destino.path;
        await destino.delete();
      }

      final cliente = _http ?? HttpClient();
      final pedido = await cliente.getUrl(Uri.parse(info.urlDownload));
      final resposta = await pedido.close();
      if (resposta.statusCode != 200) {
        debugPrint('[Instalador] download devolveu ${resposta.statusCode}');
        return null;
      }

      final total = resposta.contentLength;
      var recebido = 0;
      final saida = destino.openWrite();
      await for (final bloco in resposta) {
        saida.add(bloco);
        recebido += bloco.length;
        if (total > 0) aoProgredir?.call(recebido / total);
      }
      await saida.flush();
      await saida.close();

      if (!await _confere(destino, info.sha256!)) {
        debugPrint('[Instalador] SHA-256 não bate — ficheiro descartado');
        await destino.delete();
        return null;
      }
      return destino.path;
    } catch (erro) {
      debugPrint('[Instalador] download falhou: $erro');
      try {
        if (destino != null && await destino.exists()) await destino.delete();
      } catch (_) {
        // Não conseguir limpar não é razão para esconder o erro original.
      }
      return null;
    }
  }

  /// Entrega o ficheiro ao Android.
  ///
  /// Devolve `'instalado'`, `'pediu_confirmacao'` (o sistema decidiu
  /// perguntar — é o normal na primeira vez) ou `null` em falha.
  Future<String?> instalar(String caminho) async {
    try {
      return await _canal.invokeMethod<String>('instalar', {
        'caminho': caminho,
      });
    } on PlatformException catch (e) {
      debugPrint('[Instalador] instalar falhou: ${e.code} · ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Lê em blocos: um APK pode andar pelas dezenas de MB, e carregá-lo todo
  /// para memória para calcular o hash é pedir um estoiro num telemóvel
  /// apertado.
  Future<bool> _confere(File ficheiro, String esperado) async {
    try {
      final saida = _RecolheDigest();
      final entrada = sha256.startChunkedConversion(saida);
      await for (final bloco in ficheiro.openRead()) {
        entrada.add(bloco);
      }
      entrada.close();
      final obtido = saida.digest.toString();
      final bate = obtido.toLowerCase() == esperado.trim().toLowerCase();
      if (!bate) {
        debugPrint('[Instalador] esperado $esperado, obtido $obtido');
      }
      return bate;
    } catch (erro) {
      debugPrint('[Instalador] verificação falhou: $erro');
      return false;
    }
  }
}

/// Apanha o único `Digest` que a conversão em blocos produz no fim.
///
/// Existe para não trazer o `package:convert` só por causa do
/// `AccumulatorSink`: é uma dependência inteira para guardar um valor.
class _RecolheDigest implements Sink<Digest> {
  late final Digest digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
