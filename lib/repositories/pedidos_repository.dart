import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pedido_renovacao.dart';

class PedidosRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<PedidoRenovacao>> pendentes() async {
    final rows = await _client
        .from('pedidos_renovacao')
        .select()
        .eq('estado', 'pendente')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => PedidoRenovacao.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PedidoRenovacao?> pendentePorNif(String nif) async {
    final row = await _client
        .from('pedidos_renovacao')
        .select()
        .eq('nif', nif)
        .eq('estado', 'pendente')
        .maybeSingle();
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
