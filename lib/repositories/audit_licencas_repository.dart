import 'package:supabase_flutter/supabase_flutter.dart';

/// Uma entrada do historial de acções sobre uma licença.
class EntradaAudit {
  final int id;
  final String acao;
  final Map<String, dynamic> parametros;
  final String? actorUid;
  final String? actorRole;
  final DateTime criadoEm;

  const EntradaAudit({
    required this.id,
    required this.acao,
    required this.parametros,
    required this.criadoEm,
    this.actorUid,
    this.actorRole,
  });

  factory EntradaAudit.fromJson(Map<String, dynamic> json) => EntradaAudit(
        id: (json['id'] as num).toInt(),
        acao: json['acao'] as String? ?? '',
        parametros: (json['parametros'] as Map?)?.cast<String, dynamic>() ??
            const {},
        actorUid: json['actor_uid'] as String?,
        actorRole: json['actor_role'] as String?,
        criadoEm: DateTime.parse(json['criado_em'] as String),
      );

  /// Descrição curta dos parâmetros para a linha do historial.
  String get parametrosResumidos {
    if (parametros.isEmpty) return '';
    return parametros.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  /// Rótulo humano da acção.
  String get acaoLabel => switch (acao) {
        'prolongar' => 'Prolongou',
        'suspender' => 'Suspendeu',
        'reactivar' => 'Reactivou',
        'cancelar' => 'Cancelou',
        'mudar_tier' => 'Mudou o plano',
        _ => acao,
      };
}

/// Leitura do historial de acções remotas sobre licenças.
///
/// Lê de `public.licencas_audit` — **não** existe tabela `audit_licencas`. A
/// tabela é alimentada por duas vias: o trigger `registar_audit_licenca`
/// (qualquer escrita, `acao` a `null`) e a Edge Function `gerir-licenca`
/// (acções deliberadas, com `acao` e `actor_uid` preenchidos).
///
/// Filtra-se por `acao is not null` porque só essas respondem a "quem fez o
/// quê": as do trigger têm `actor_uid` nulo quando a escrita vem da function
/// (service_role não tem `auth.uid()`), e seriam ruído duplicado no historial.
class AuditLicencasRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Últimas [limite] acções sobre a licença [licencaId], mais recentes
  /// primeiro.
  Future<List<EntradaAudit>> porLicenca(
    String licencaId, {
    int limite = 20,
  }) async {
    final rows = await _client
        .from('licencas_audit')
        .select('id, acao, parametros, actor_uid, actor_role, criado_em')
        .eq('licenca_id', licencaId)
        .not('acao', 'is', null)
        .order('criado_em', ascending: false)
        .limit(limite);
    return (rows as List)
        .map((e) => EntradaAudit.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
