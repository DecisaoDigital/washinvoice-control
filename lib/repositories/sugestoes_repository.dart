import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/sugestao.dart';

class SugestoesRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Sugestões por ler (não lidas e não arquivadas), mais recentes primeiro.
  Future<List<Sugestao>> listarPorLer({String? app}) async {
    var q = _client
        .from('sugestoes')
        .select()
        .eq('lida', false)
        .eq('arquivada', false);
    if (app != null) q = q.eq('app', app);
    final rows = await q.order('criado_em', ascending: false);
    return (rows as List)
        .map((e) => Sugestao.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sugestões arquivadas, mais recentes primeiro.
  Future<List<Sugestao>> listarArquivo({String? app}) async {
    var q = _client.from('sugestoes').select().eq('arquivada', true);
    if (app != null) q = q.eq('app', app);
    final rows = await q.order('criado_em', ascending: false);
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

  /// Grava a resposta do César; o terminal que enviou a sugestão vê-a no POS /
  /// Fist / Fist OP através da edge function `respostas-sugestoes`.
  Future<void> responder(String sugestaoId, String texto) async {
    await _client.from('sugestoes_respostas').insert({
      'sugestao_id': sugestaoId,
      'texto': texto,
    });
  }
}
