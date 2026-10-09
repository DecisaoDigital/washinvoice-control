import 'package:supabase_flutter/supabase_flutter.dart';

/// Aviso de um pedido novo do site decisaodigital.pt. Só a referência: o nome,
/// o telefone e as notas ficam no servidor do site e nunca chegam aqui.
class PedidoSiteAviso {
  const PedidoSiteAviso({required this.ref, required this.criadoEm});

  final String ref;
  final DateTime criadoEm;

  factory PedidoSiteAviso.fromJson(Map<String, dynamic> j) => PedidoSiteAviso(
        ref: j['ref'] as String,
        criadoEm: DateTime.parse(j['criado_em'] as String),
      );
}

class PedidosSiteRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Avisos por ver (`visto_em` nulo), mais recentes primeiro.
  Future<List<PedidoSiteAviso>> listarPorVer() async {
    final rows = await _client
        .from('pedidos_site_avisos')
        .select('ref, criado_em')
        .filter('visto_em', 'is', null)
        .order('criado_em', ascending: false);
    return (rows as List)
        .map((e) => PedidoSiteAviso.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> marcarVisto(String ref) async {
    await _client
        .from('pedidos_site_avisos')
        .update({'visto_em': DateTime.now().toUtc().toIso8601String()}).eq(
            'ref', ref);
  }
}
