import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pedido_renovacao.dart';

class PedidosRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<PedidoRenovacao>> pendentes({String? app}) async {
    var q = _client
        .from('pedidos_renovacao')
        .select()
        .eq('estado', 'pendente');
    if (app != null) q = q.eq('app', app);
    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .map((e) => PedidoRenovacao.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Pedido pendente de um NIF. Aceita [app] porque o mesmo NIF pode ter
  /// pedidos em apps diferentes — sem o filtro, o `maybeSingle()` rebentaria
  /// com duas linhas em vez de devolver a do ecrã que está aberto.
  Future<PedidoRenovacao?> pendentePorNif(String nif, {String? app}) async {
    var q = _client
        .from('pedidos_renovacao')
        .select()
        .eq('nif', nif)
        .eq('estado', 'pendente');
    if (app != null) q = q.eq('app', app);
    final row = await q.maybeSingle();
    if (row == null) return null;
    return PedidoRenovacao.fromJson(row);
  }

  Future<void> confirmar(String id) async {
    await _client
        .from('pedidos_renovacao')
        .update({
          'estado': 'confirmado',
          'confirmado_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }
}
