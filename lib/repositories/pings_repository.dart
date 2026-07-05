import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ping.dart';

class PingsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Último ping de cada machine_id (para saber a última actividade).
  ///
  /// Faz a redução no cliente: ordena por data desc e mantém o primeiro
  /// ping de cada machine_id.
  Future<List<Ping>> ultimosPorInstalacao() async {
    final rows = await _client
        .from('pings')
        .select()
        .order('created_at', ascending: false);
    final vistos = <String>{};
    final ultimos = <Ping>[];
    for (final row in rows as List) {
      final p = Ping.fromJson(row as Map<String, dynamic>);
      if (vistos.add(p.machineId)) {
        ultimos.add(p);
      }
    }
    return ultimos;
  }

  /// Histórico de pings de um machine_id específico.
  Future<List<Ping>> historico(String machineId, {int limite = 20}) async {
    final rows = await _client
        .from('pings')
        .select()
        .eq('machine_id', machineId)
        .order('created_at', ascending: false)
        .limit(limite);
    return (rows as List)
        .map((e) => Ping.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Todas as instalações com localização para o mapa (último ping geolocalizado
  /// de cada machine_id).
  Future<List<Ping>> comLocalizacao() async {
    final rows = await _client
        .from('pings')
        .select()
        .not('lat', 'is', null)
        .not('lon', 'is', null)
        .order('created_at', ascending: false);
    final vistos = <String>{};
    final resultado = <Ping>[];
    for (final row in rows as List) {
      final p = Ping.fromJson(row as Map<String, dynamic>);
      if (vistos.add(p.machineId)) {
        resultado.add(p);
      }
    }
    return resultado;
  }
}
