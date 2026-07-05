import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Assinatura de licenças (HMAC-SHA256) — **Dart puro**, sem dependências de
/// Flutter, para poder ser partilhado entre a app ([LicencaService]) e a
/// ferramenta de emissão de licenças (`tool/emitir_licenca.dart`).
///
/// Mantém **uma só fonte de verdade** para a chave privada e para o algoritmo:
/// a app valida com [assinarLicenca] e a ferramenta assina com a mesma função.
///
/// ⚠️ ANTES DE PRODUÇÃO: substituir [_hmacKey] por uma chave nova (gerar com
/// `dart run tool/gerar_chave.dart` ou equivalente). A chave abaixo foi gerada
/// aleatoriamente para o beta — como é simétrica, vive sempre no binário da app;
/// trocá-la invalida todas as licenças já emitidas, por isso só se troca uma vez,
/// antes de distribuir.
const String _hmacKey =
    'eB3FDymMljqJ3h3OayrrZ9QEN5TD7AINYtxaNpxfjCkyAo5Cj66hZDDp9BOj5iJ6';

/// String base assinada: `nif|machine_id|validade|plano` (campos nulos → vazio).
/// Tem de ser idêntica na emissão e na validação.
///
/// [serie] (série documental do terminal, ex.: `FT-T1`) é **opcional** e
/// **retrocompatível**: quando ausente/vazia a base é **idêntica** às licenças
/// já emitidas; quando presente, é acrescentada no fim (`…|plano|serie`), de
/// modo que só as licenças novas (com série) a incluem na assinatura.
String baseAssinatura({
  required String? nif,
  required String machineId,
  required String validade,
  required String? plano,
  String? serie,
}) {
  final base = '${nif ?? ''}|$machineId|$validade|${plano ?? ''}';
  return (serie == null || serie.isEmpty) ? base : '$base|$serie';
}

/// Assinatura HMAC-SHA256 (hex) de uma licença.
String assinarLicenca({
  required String? nif,
  required String machineId,
  required String validade,
  required String? plano,
  String? serie,
}) {
  final base = baseAssinatura(
    nif: nif,
    machineId: machineId,
    validade: validade,
    plano: plano,
    serie: serie,
  );
  return Hmac(sha256, utf8.encode(_hmacKey)).convert(utf8.encode(base)).toString();
}
