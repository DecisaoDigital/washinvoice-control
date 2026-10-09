import 'package:supabase_flutter/supabase_flutter.dart';

/// Uma linha do Histórico: o que chegou ao Control, o que se fez e quando.
class RegistoHistorico {
  const RegistoHistorico({
    required this.id,
    required this.criadoEm,
    required this.tipo,
    required this.titulo,
    required this.accao,
    this.app,
    this.pedido,
    this.machineId,
  });

  final String id;
  final DateTime criadoEm;

  /// Etiqueta do assunto («Pedido de acesso», «Licença expirada», …).
  final String tipo;
  final String? app;
  final String titulo;

  /// O que foi pedido / o que estava à espera (texto livre curto).
  final String? pedido;

  /// O que o Cesar fez («Aceite», «Renovada para Pro até 09/11/2026», …).
  final String accao;
  final String? machineId;

  factory RegistoHistorico.fromJson(Map<String, dynamic> j) => RegistoHistorico(
        id: j['id'] as String,
        criadoEm: DateTime.parse(j['criado_em'] as String).toLocal(),
        tipo: j['tipo'] as String,
        app: j['app'] as String?,
        titulo: j['titulo'] as String,
        pedido: j['pedido'] as String?,
        accao: j['accao'] as String,
        machineId: j['machine_id'] as String?,
      );
}

class HistoricoRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> registar({
    required String tipo,
    required String titulo,
    required String accao,
    String? app,
    String? pedido,
    String? machineId,
  }) async {
    await _client.from('control_historico').insert({
      'tipo': tipo,
      'titulo': titulo,
      'accao': accao,
      'app': app,
      'pedido': pedido,
      'machine_id': machineId,
    });
  }

  /// Os registos mais recentes primeiro.
  Future<List<RegistoHistorico>> recentes({int limite = 300}) async {
    final rows = await _client
        .from('control_historico')
        .select()
        .order('criado_em', ascending: false)
        .limit(limite);
    return (rows as List)
        .map((e) => RegistoHistorico.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
