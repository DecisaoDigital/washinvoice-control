import 'package:supabase_flutter/supabase_flutter.dart';

/// Pedido de acesso ao **Punho** (tabela `punho_pedidos_acesso`).
///
/// Nada a ver com [PedidoAcesso] de `acessos_repository.dart`, que é o acesso
/// ao próprio Control. Os dois namespaces são separados de propósito: um é a
/// equipa do escritório, o outro são clientes das apps.
class PunhoPedido {
  final String id, userId, email, organizacaoIndicada, perfil, origem, estado;
  final String? nome;
  final DateTime criadoEm;
  final DateTime? decididoEm;

  /// Empresa do convite que originou o pedido (só em [porConvite]).
  final String? conviteEmpresaId, conviteEmpresaNome;
  final DateTime? conviteCriadoEm;

  /// Empresa já associada ao pedido (preenchida na aprovação).
  final String? empresaId, empresaNome;

  PunhoPedido.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      userId = json['user_id'] as String,
      nome = json['nome'] as String?,
      email = json['email'] as String,
      organizacaoIndicada = json['organizacao_indicada'] as String,
      perfil = json['perfil'] as String,
      origem = json['origem'] as String,
      estado = json['estado'] as String,
      criadoEm = DateTime.parse(json['criado_em'] as String),
      decididoEm = json['decidido_em'] == null
          ? null
          : DateTime.parse(json['decidido_em'] as String),
      conviteEmpresaId = json['convite_empresa_id'] as String?,
      conviteEmpresaNome = json['convite_empresa_nome'] as String?,
      conviteCriadoEm = json['convite_criado_em'] == null
          ? null
          : DateTime.parse(json['convite_criado_em'] as String),
      empresaId = json['empresa_id'] as String?,
      empresaNome = json['empresa_nome'] as String?;

  bool get porConvite => origem == 'convite';
  String get nomeApresentavel =>
      (nome?.trim().isNotEmpty ?? false) ? nome!.trim() : 'Sem nome';
  String get perfilApresentavel => perfil == 'gestor' ? 'Gestor' : 'Colaborador';

  /// Empresa a que o acesso vai ficar ligado, quando já se sabe qual é.
  String? get empresaDestinoNome => conviteEmpresaNome ?? empresaNome;
}

/// Empresa do Punho com a ocupação actual.
class PunhoEmpresa {
  final String id, nome;
  final int limiteUtilizadores, ativos;

  PunhoEmpresa.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      nome = json['nome'] as String,
      limiteUtilizadores = (json['limite_utilizadores'] as num).toInt(),
      ativos = (json['ativos_count'] as num).toInt();

  String get ocupacao => '$ativos / $limiteUtilizadores';
  bool get noLimite => limiteUtilizadores > 0 && ativos >= limiteUtilizadores;
}

/// Estados possíveis de um pedido, pela ordem em que interessam ao admin.
const punhoEstados = ['pendente', 'aprovado', 'recusado', 'revogado'];

/// Acesso do Control às RPCs de administração do Punho.
///
/// Toda a escrita passa por `punho_decidir_pedido`: não há UPDATE directo em
/// `punho_membros` a partir da app. As RPCs verificam `is_admin()` no servidor
/// — o que a UI faz é só apresentação.
class PunhoAdminRepository {
  PunhoAdminRepository([SupabaseClient? db]) : _injectado = db;
  final SupabaseClient? _injectado;

  // Resolvido a cada uso para os testes poderem estender esta classe sem
  // exigir um Supabase inicializado.
  SupabaseClient get _db => _injectado ?? Supabase.instance.client;

  Future<List<PunhoPedido>> listarPedidos({String estado = 'pendente'}) async {
    final linhas = await _db.rpc(
      'punho_listar_pedidos_admin',
      params: {'p_estado': estado},
    );
    return (linhas as List)
        .cast<Map<String, dynamic>>()
        .map(PunhoPedido.fromJson)
        .toList();
  }

  Future<List<PunhoEmpresa>> listarEmpresas() async {
    final linhas = await _db.rpc('punho_listar_empresas_admin');
    return (linhas as List)
        .cast<Map<String, dynamic>>()
        .map(PunhoEmpresa.fromJson)
        .toList();
  }

  /// [decisao] é `aprovar`, `recusar` ou `revogar`.
  ///
  /// [empresaId] só conta em pedidos livres: `null` cria empresa nova com o
  /// nome indicado no registo. Num pedido por convite o servidor ignora-o.
  Future<Map<String, dynamic>> decidir(
    String pedidoId,
    String decisao, {
    String? empresaId,
    int limiteUtilizadores = 1,
  }) async {
    final resposta = await _db.rpc(
      'punho_decidir_pedido',
      params: {
        'p_pedido_id': pedidoId,
        'p_decisao': decisao,
        'p_empresa_id': empresaId,
        'p_limite_utilizadores': limiteUtilizadores,
      },
    );
    return (resposta as Map).cast<String, dynamic>();
  }

  /// Apaga o pedido em definitivo. Devolve o que foi apagado — nome, email e
  /// o estado em que estava — para quem chama poder dizê-lo.
  ///
  /// O servidor recusa a quem não for administrador global, e um pedido
  /// aprovado leva o acesso da pessoa com ele: ver `punho_apagar_pedido`.
  Future<Map<String, dynamic>> apagar(String pedidoId) async {
    final resposta = await _db.rpc(
      'punho_apagar_pedido',
      params: {'p_pedido_id': pedidoId},
    );
    return (resposta as Map).cast<String, dynamic>();
  }

  /// Muda o limite de colaboradores activos de uma empresa já existente,
  /// fora do fluxo de aprovação de um pedido (que só o define na criação).
  Future<Map<String, dynamic>> definirLimite(
    String empresaId,
    int novoLimite,
  ) async {
    final resposta = await _db.rpc(
      'punho_definir_limite',
      params: {'p_empresa_id': empresaId, 'p_novo_limite': novoLimite},
    );
    return (resposta as Map).cast<String, dynamic>();
  }
}
