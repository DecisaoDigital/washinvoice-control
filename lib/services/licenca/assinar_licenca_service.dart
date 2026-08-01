import 'package:supabase_flutter/supabase_flutter.dart';

/// Licença assinada pelo servidor, tal como volta da Edge Function
/// `assinar-licenca`. Os campos são os que foram **efectivamente assinados** —
/// o `licenca.json` escreve-se a partir daqui e não de cópias locais, senão
/// bastava um valor diferente para a assinatura não bater.
class LicencaAssinada {
  final int versaoAssinatura;
  final String assinatura;

  final String nif;
  final String? nome;
  final String? chaveMestre;
  final String machineId;
  final String plano;

  /// `AAAA-MM-DD`, o formato exacto que entrou na base assinada.
  final String validade;

  final String? serie;

  const LicencaAssinada({
    required this.versaoAssinatura,
    required this.assinatura,
    required this.nif,
    this.nome,
    this.chaveMestre,
    required this.machineId,
    required this.plano,
    required this.validade,
    this.serie,
  });

  factory LicencaAssinada.fromJson(Map<String, dynamic> json) {
    final assinatura = json['assinatura'];
    if (assinatura is! String || assinatura.isEmpty) {
      throw const AssinarLicencaException('resposta sem assinatura');
    }
    final campos = json['campos'];
    if (campos is! Map) {
      throw const AssinarLicencaException('resposta sem os campos assinados');
    }
    final c = Map<String, dynamic>.from(campos);

    String obrigatorio(String chave) {
      final v = c[chave];
      if (v is! String || v.isEmpty) {
        throw AssinarLicencaException('campo "$chave" em falta na resposta');
      }
      return v;
    }

    return LicencaAssinada(
      versaoAssinatura: (json['versao_assinatura'] as num?)?.toInt() ?? 2,
      assinatura: assinatura,
      nif: obrigatorio('nif'),
      nome: c['nome'] as String?,
      chaveMestre: c['chave_mestre'] as String?,
      machineId: obrigatorio('machine_id'),
      plano: obrigatorio('plano'),
      validade: obrigatorio('validade'),
      serie: c['serie'] as String?,
    );
  }
}

class AssinarLicencaException implements Exception {
  final String mensagem;
  const AssinarLicencaException(this.mensagem);

  @override
  String toString() => mensagem;
}

/// Pede ao servidor que assine a licença de um terminal.
///
/// **O Control já não sabe assinar** — e é esse o ponto. A chave privada Ed25519
/// vive só no secret `LICENCA_ED25519_PRIVATE_KEY` do Supabase; aqui não há
/// chave nenhuma para extrair de um APK.
///
/// O Control também não escolhe *o que* é assinado: manda o `machine_id` (e a
/// série, quando é o momento de a definir) e o servidor assina o que tem na
/// base de dados para aquele terminal.
class AssinarLicencaService {
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> body)
      _invocar;

  AssinarLicencaService(SupabaseClient client)
      : _invocar = ((body) async {
          final resp = await client.functions.invoke('assinar-licenca',
              body: body);
          final data = resp.data;
          if (data is Map) return Map<String, dynamic>.from(data);
          throw const AssinarLicencaException('resposta inválida da function');
        });

  /// Para testes: injecta o invocador e dispensa a rede.
  AssinarLicencaService.comInvocador(this._invocar);

  Future<LicencaAssinada> assinar(String machineId, {String? serie}) async {
    final data = await _invocar({
      'machine_id': machineId,
      if (serie != null && serie.isNotEmpty) 'serie': serie,
    });
    if (data['ok'] != true) {
      throw AssinarLicencaException(
          data['erro'] as String? ?? 'falha desconhecida a assinar');
    }
    return LicencaAssinada.fromJson(data);
  }
}
