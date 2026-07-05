import 'dart:convert';

import '../models/licenca.dart';
import 'licenca_assinatura.dart';

/// Emissão do **licenca.json** assinado — **idêntico byte-a-byte** ao que a CLI
/// `tool/emitir_licenca.dart` do WashFactura produz para os mesmos inputs:
/// mesma ordem de campos, mesmo formato de `validade` (`AAAA-MM-DD`), mesma base
/// assinada e mesma chave HMAC (`licenca_assinatura.dart`, cópia verbatim do
/// WashFactura), mesma indentação (2 espaços).
///
/// ⚠️ Manter em sincronia com a CLI: se uma mudar o formato, a outra tem de
/// mudar igual — senão uma licença gerada por uma fica inválida na outra sem
/// aviso. O teste `licenca_emissao_test.dart` fixa a assinatura esperada.
const String versaoTermosLicenca = '1.0';

/// Validade como `AAAA-MM-DD` (o formato que a CLI assina e grava).
String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Conteúdo (JSON indentado) do `licenca.json`. [serie] é opcional
/// (multi-terminal) e retrocompatível — ausente/vazia produz exactamente o
/// formato antigo.
String construirLicencaJson({
  required String nif,
  String? nome,
  required String machineId,
  required String plano,
  required DateTime validade,
  String? serie,
  String versaoTermos = versaoTermosLicenca,
}) {
  final validadeStr = ymd(validade);
  final serieLimpa =
      (serie != null && serie.trim().isNotEmpty) ? serie.trim() : null;
  final assinatura = assinarLicenca(
    nif: nif,
    machineId: machineId,
    validade: validadeStr,
    plano: plano,
    serie: serieLimpa,
  );
  final licenca = <String, dynamic>{
    'nif': nif,
    'nome': nome,
    'machine_id': machineId,
    'plano': plano,
    'validade': validadeStr,
    if (serieLimpa != null) 'serie': serieLimpa,
    'versao_termos': versaoTermos,
    'assinatura': assinatura,
  };
  return const JsonEncoder.withIndent('  ').convert(licenca);
}

/// Gera o `licenca.json` **com verificação de colisão de série** (ponto 3 da
/// decisão). [verificarColisao] devolve uma licença conflituante (mesma série,
/// terminal diferente) ou `null` — injectável para teste. Lança [StateError],
/// **bloqueando** a geração, se a série for vazia ou houver colisão (nunca deixa
/// passar em silêncio).
Future<String> gerarLicencaJsonComVerificacao({
  required Licenca licenca,
  required String serie,
  required Future<Licenca?> Function(String serie, String excetoMachineId)
      verificarColisao,
}) async {
  final s = serie.trim();
  if (s.isEmpty) {
    throw StateError('Indica a série do terminal (ex.: FT-T1).');
  }
  final conflito = await verificarColisao(s, licenca.machineId);
  if (conflito != null) {
    throw StateError(
        'Já existe uma licença activa com a série "$s" noutro terminal '
        '(machine_id ${conflito.machineId}). Usa uma série diferente antes de '
        'gerar a licença.');
  }
  return construirLicencaJson(
    nif: licenca.nif,
    nome: licenca.nome,
    machineId: licenca.machineId,
    plano: licenca.plano,
    validade: licenca.validade,
    serie: s,
  );
}
