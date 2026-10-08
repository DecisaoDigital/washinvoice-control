import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pedido_ajuda.dart';

class PedidosAjudaRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Pedidos ainda por resolver, mais recentes primeiro.
  Future<List<PedidoAjuda>> listarAbertos({String? app}) async {
    var q = _client
        .from('pedidos_ajuda')
        .select()
        .filter('resolvido_em', 'is', null);
    if (app != null) q = q.eq('app', app);
    final rows = await q.order('criado_em', ascending: false);
    return (rows as List)
        .map((e) => PedidoAjuda.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Pedidos já resolvidos, resolução mais recente primeiro.
  Future<List<PedidoAjuda>> listarHistorico({String? app}) async {
    var q = _client
        .from('pedidos_ajuda')
        .select()
        .not('resolvido_em', 'is', null);
    if (app != null) q = q.eq('app', app);
    final rows = await q.order('resolvido_em', ascending: false);
    return (rows as List)
        .map((e) => PedidoAjuda.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Marca um pedido como resolvido (resolvido_em = agora).
  Future<void> marcarResolvido(String id) async {
    await _client
        .from('pedidos_ajuda')
        .update({'resolvido_em': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Volta a abrir um pedido resolvido (resolvido_em = nulo). É o «Anular» do
  /// «Resolvido»: um update igual ao de [marcarResolvido], pela mesma política.
  Future<void> reabrir(String id) async {
    await _client
        .from('pedidos_ajuda')
        .update({'resolvido_em': null})
        .eq('id', id);
  }
}
