import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente.dart';

class ClientesRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Cliente>> listar() async {
    final rows = await _client
        .from('clientes')
        .select()
        .order('nome', ascending: true);
    return (rows as List)
        .map((e) => Cliente.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Cliente?> porNif(String nif) async {
    final row =
        await _client.from('clientes').select().eq('nif', nif).maybeSingle();
    if (row == null) return null;
    return Cliente.fromJson(row);
  }

  Future<void> criar(Cliente c) async {
    await _client.from('clientes').insert(c.toInsertJson());
  }

  /// Cria um cliente novo (id e created_em gerados pela base de dados) e
  /// devolve-o já com o id atribuído.
  Future<Cliente> criarNovo({
    required String nif,
    required String nome,
    String? email,
    String? telemovel,
    String? notas,
  }) async {
    final row = await _client
        .from('clientes')
        .insert({
          'nif': nif,
          'nome': nome,
          'email': email,
          'telemovel': telemovel,
          'notas': notas,
        })
        .select()
        .single();
    return Cliente.fromJson(row);
  }

  Future<void> actualizar(Cliente c) async {
    // toUpdateJson exclui id/created_at (evita enviá-los no UPDATE).
    await _client.from('clientes').update(c.toUpdateJson()).eq('id', c.id);
  }
}
