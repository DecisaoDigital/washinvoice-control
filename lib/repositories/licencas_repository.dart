import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/licenca.dart';

class LicencasRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Licenca>> listar() async {
    final rows = await _client
        .from('licencas')
        .select()
        .order('validade', ascending: true);
    return (rows as List)
        .map((e) => Licenca.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Licenca?> porMachineId(String machineId) async {
    final row = await _client
        .from('licencas')
        .select()
        .eq('machine_id', machineId)
        .maybeSingle();
    if (row == null) return null;
    return Licenca.fromJson(row);
  }

  Future<Licenca?> porNif(String nif) async {
    final row =
        await _client.from('licencas').select().eq('nif', nif).maybeSingle();
    if (row == null) return null;
    return Licenca.fromJson(row);
  }

  Future<List<Licenca>> aExpirar({int dias = 15}) async {
    final agora = DateTime.now();
    final limite = agora.add(Duration(days: dias));
    final rows = await _client
        .from('licencas')
        .select()
        .eq('activa', true)
        .gte('validade', agora.toIso8601String())
        .lte('validade', limite.toIso8601String())
        .order('validade', ascending: true);
    return (rows as List)
        .map((e) => Licenca.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cria uma licença nova (id e created_em gerados pela base de dados).
  Future<void> criar({
    required String machineId,
    required String nif,
    String? nome,
    String? clienteId,
    required String plano,
    required DateTime validade,
    bool activa = true,
  }) async {
    await _client.from('licencas').insert({
      'machine_id': machineId,
      'nif': nif,
      'nome': nome,
      'cliente_id': clienteId,
      'plano': plano,
      'validade': validade.toIso8601String(),
      'activa': activa,
    });
  }

  /// Lista os machine_id que já têm licença (para detetar instalações novas).
  Future<Set<String>> machineIdsComLicenca() async {
    final rows = await _client.from('licencas').select('machine_id');
    return {
      for (final r in rows as List) (r as Map<String, dynamic>)['machine_id'] as String,
    };
  }

  /// **Colisão de série**: devolve uma licença **activa** com a mesma [serie]
  /// mas machine_id **diferente** de [excetoMachineId] (dois terminais a apontar
  /// para a mesma série — exactamente o que "série por terminal" evita), ou
  /// `null` se não houver. Usado ANTES de gerar um licenca.json com série.
  Future<Licenca?> licencaActivaComSerie(
    String serie, {
    required String excetoMachineId,
  }) async {
    final rows = await _client
        .from('licencas')
        .select()
        .eq('serie', serie)
        .eq('activa', true)
        .neq('machine_id', excetoMachineId);
    final lista = rows as List;
    if (lista.isEmpty) return null;
    return Licenca.fromJson(lista.first as Map<String, dynamic>);
  }

  /// Regista a série do terminal na licença (ao gerar o licenca.json).
  Future<void> definirSerie(String id, String serie) async {
    await _client.from('licencas').update({'serie': serie}).eq('id', id);
  }

  Future<void> activar(String id, {required bool activa}) async {
    await _client.from('licencas').update({'activa': activa}).eq('id', id);
  }

  Future<void> actualizar(Licenca l) async {
    await _client.from('licencas').update(l.toJson()).eq('id', l.id);
  }
}
