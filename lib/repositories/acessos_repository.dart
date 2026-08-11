import 'package:supabase_flutter/supabase_flutter.dart';

class PedidoAcesso {
  final String id, nome, email, organizacao, cargo, origem, estado;
  final String? organizacaoId;
  final DateTime criadoEm;

  PedidoAcesso.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        nome = (json['nome'] as String?)?.trim().isNotEmpty == true
            ? json['nome'] as String
            : 'Sem nome',
        email = json['email'] as String,
        organizacao = json['organizacao_indicada'] as String,
        organizacaoId = json['organizacao_id'] as String?,
        cargo = json['cargo'] as String,
        origem = json['origem'] as String,
        estado = json['estado'] as String,
        criadoEm = DateTime.parse(json['criado_em'] as String);
}

class OrganizacaoAcesso {
  final String id, nome;
  final int limite;
  OrganizacaoAcesso.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        nome = json['nome'] as String,
        limite = json['limite_utilizadores'] as int;
}

class AcessosRepository {
  final SupabaseClient? _injectado;
  AcessosRepository([SupabaseClient? db]) : _injectado = db;

  // Resolvido a cada uso (não no construtor) para que um fake de teste possa
  // estender esta classe sem obrigar a haver um Supabase inicializado.
  SupabaseClient get _db => _injectado ?? Supabase.instance.client;

  Future<String> meuEstado() async =>
      await _db.rpc('meu_estado_acesso') as String;

  Future<bool> souAdminGlobal() async => await _db.rpc('is_admin') as bool;

  Future<Map<String, dynamic>> criarConvite(String email, String cargo) async =>
      (await _db.rpc('criar_convite_organizacao', params: {
        'p_email': email,
        'p_cargo': cargo,
      }) as List).first as Map<String, dynamic>;

  Future<List<PedidoAcesso>> listarPendentes() async {
    final rows = await _db.from('pedidos_acesso').select().eq('estado', 'pendente')
        .order('criado_em', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>().map(PedidoAcesso.fromJson).toList();
  }

  /// Contas já aprovadas. Servem para revogar acessos e para calcular a
  /// ocupação (`ativos / limite`) de cada organização.
  Future<List<PedidoAcesso>> listarAprovados() async {
    final rows = await _db.from('pedidos_acesso').select().eq('estado', 'aprovado')
        .order('criado_em', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>().map(PedidoAcesso.fromJson).toList();
  }

  Future<List<OrganizacaoAcesso>> listarOrganizacoes() async {
    final rows = await _db.from('organizacoes').select().order('nome', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>().map(OrganizacaoAcesso.fromJson).toList();
  }

  Future<void> decidir(String id, String decisao, {String? organizacaoId}) =>
      _db.rpc('decidir_pedido_acesso', params: {
        'p_pedido_id': id,
        'p_decisao': decisao,
        'p_organizacao_id': organizacaoId,
      });

  /// Apaga o pedido de acesso em definitivo.
  ///
  /// O servidor recusa duas coisas: quem não for administrador global, e o
  /// próprio pedido de quem chama — apagar o seu deixava-o de fora do Control,
  /// que é a app onde se voltaria a autorizar.
  Future<Map<String, dynamic>> apagar(String id) async {
    final resposta = await _db.rpc(
      'apagar_pedido_acesso',
      params: {'p_pedido_id': id},
    );
    return (resposta as Map).cast<String, dynamic>();
  }
}
