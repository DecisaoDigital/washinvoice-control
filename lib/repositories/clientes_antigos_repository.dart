import 'package:supabase_flutter/supabase_flutter.dart';

/// Um cliente que o Cesar deixou de querer tratar. Sai do «Agora» e fica em
/// «Clientes › Antigos»; pode ser reactivado.
class ClienteAntigo {
  const ClienteAntigo({
    required this.machineId,
    required this.desde,
    this.app,
    this.titulo,
  });

  final String machineId;
  final String? app;
  final String? titulo;
  final DateTime desde;

  factory ClienteAntigo.fromJson(Map<String, dynamic> j) => ClienteAntigo(
        machineId: j['machine_id'] as String,
        app: j['app'] as String?,
        titulo: j['titulo'] as String?,
        desde: DateTime.parse(j['desde'] as String).toLocal(),
      );
}

class ClientesAntigosRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<ClienteAntigo>> listar() async {
    final rows =
        await _client.from('clientes_antigos').select().order('desde', ascending: false);
    return (rows as List)
        .map((e) => ClienteAntigo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> passarParaAntigo({
    required String machineId,
    String? app,
    String? titulo,
  }) async {
    await _client.from('clientes_antigos').upsert({
      'machine_id': machineId,
      'app': app,
      'titulo': titulo,
    });
  }

  Future<void> reactivar(String machineId) async {
    await _client.from('clientes_antigos').delete().eq('machine_id', machineId);
  }
}
