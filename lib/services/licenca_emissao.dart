import 'dart:convert';

import '../models/licenca.dart';
import 'licenca/assinar_licenca_service.dart';

/// Escrita do **licenca.json** a partir do que o servidor assinou.
///
/// ## O Control já não assina
///
/// Até à v1.8.5 o ficheiro era assinado aqui, com uma chave HMAC **simétrica**
/// que vivia no binário — a mesma que estava no POS. Quem extraísse qualquer um
/// dos dois passava a emitir licenças válidas.
///
/// Agora quem assina é a Edge Function `assinar-licenca`, com Ed25519 e a chave
/// privada num secret do Supabase. **Este ficheiro deixou de ter chave
/// nenhuma** — e o APK do Control também não, que era metade do problema.
///
/// O que aqui ficou é só a montagem do JSON, a partir dos campos que voltaram
/// assinados. Nada é recalculado localmente: se um valor diferisse do que foi
/// assinado, a assinatura não batia no terminal e a licença era recusada.
const String versaoTermosLicenca = '1.0';

/// Validade como `AAAA-MM-DD` (o formato que a CLI assina e grava).
String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Monta o `licenca.json` (JSON indentado) a partir da [LicencaAssinada] que o
/// servidor devolveu.
///
/// **Não recalcula nada.** Cada campo sai tal e qual como foi assinado; a única
/// coisa acrescentada é `versao_termos`, que fica de fora da base assinada e
/// sempre esteve.
///
/// `versao_assinatura` é o que diz ao POS com que algoritmo verificar: ausente
/// ou `1` = HMAC antigo, `2` = Ed25519. As licenças que este código escreve são
/// todas v2.
String construirLicencaJson(
  LicencaAssinada assinada, {
  String versaoTermos = versaoTermosLicenca,
}) {
  final licenca = <String, dynamic>{
    'nif': assinada.nif,
    'nome': assinada.nome,
    if (assinada.chaveMestre != null) 'chave_mestre': assinada.chaveMestre,
    'machine_id': assinada.machineId,
    'plano': assinada.plano,
    'validade': assinada.validade,
    if (assinada.serie != null) 'serie': assinada.serie,
    'versao_termos': versaoTermos,
    'versao_assinatura': assinada.versaoAssinatura,
    'assinatura': assinada.assinatura,
  };
  return const JsonEncoder.withIndent('  ').convert(licenca);
}

/// Gera o `licenca.json` **com verificação de colisão de série** (ponto 3 da
/// decisão). [verificarColisao] devolve uma licença conflituante (mesma série,
/// terminal diferente) ou `null` — injectável para teste. Lança [StateError],
/// **bloqueando** a geração, se a série for vazia ou houver colisão (nunca deixa
/// passar em silêncio).
Future<String> gerarLicencaJsonComVerificacao({
  required String machineId,
  required String serie,
  required Future<Licenca?> Function(String serie, String excetoMachineId)
      verificarColisao,
  required Future<LicencaAssinada> Function(String machineId, String serie)
      assinar,
}) async {
  final s = serie.trim();
  if (s.isEmpty) {
    throw StateError('Indica a série do terminal (ex.: FT-T1).');
  }
  final conflito = await verificarColisao(s, machineId);
  if (conflito != null) {
    throw StateError(
        'Já existe uma licença activa com a série "$s" noutro terminal '
        '(machine_id ${conflito.machineId}). Usa uma série diferente antes de '
        'gerar a licença.');
  }
  // A colisão de série é verificada ANTES de assinar, de propósito: assinar
  // grava a série na linha, e gravar uma série que colide com outro terminal
  // era o que esta verificação existe para impedir.
  return construirLicencaJson(await assinar(machineId, s));
}
