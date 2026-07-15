import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sugestao.dart';

class SugestoesRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Sugestões por ler (não lidas e não arquivadas), mais recentes primeiro.
  Future<List<Sugestao>> listarPorLer() async {
    final rows = await _client
        .from('sugestoes')
        .select()
        .eq('lida', false)
        .eq('arquivada', false)
        .order('criado_em', ascending: false);
    return (rows as List)
        .map((e) => Sugestao.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sugestões arquivadas, mais recentes primeiro.
  Future<List<Sugestao>> listarArquivo() async {
    final rows = await _client
        .from('sugestoes')
        .select()
        .eq('arquivada', true)
        .order('criado_em', ascending: false);
    return (rows as List)
        .map((e) => Sugestao.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> marcarLida(String id) async {
    await _client.from('sugestoes').update({'lida': true}).eq('id', id);
  }

  Future<void> marcarMarcada(String id, bool valor) async {
    await _client.from('sugestoes').update({'marcada': valor}).eq('id', id);
  }

  /// Arquiva (e marca como lida) uma sugestão.
  Future<void> arquivar(String id) async {
    await _client
        .from('sugestoes')
        .update({'arquivada': true, 'lida': true})
        .eq('id', id);
  }
}
