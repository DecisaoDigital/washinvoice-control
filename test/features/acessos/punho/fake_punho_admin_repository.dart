import 'package:washinvoice_control/repositories/punho_admin_repository.dart';

PunhoPedido pedidoPunho({
  String id = 'p1',
  String? nome = 'Ana Silva',
  String email = 'ana@exemplo.pt',
  String organizacao = 'Terraplanagens Ana',
  String perfil = 'gestor',
  String origem = 'livre',
  String estado = 'pendente',
  String? conviteEmpresaId,
  String? conviteEmpresaNome,
  String? empresaId,
  String? empresaNome,
}) => PunhoPedido.fromJson({
  'id': id,
  'user_id': 'u-$id',
  'nome': nome,
  'email': email,
  'organizacao_indicada': organizacao,
  'perfil': perfil,
  'origem': origem,
  'estado': estado,
  'criado_em': '2026-07-20T10:00:00Z',
  'decidido_em': null,
  'convite_id': origem == 'convite' ? 'cv-$id' : null,
  'convite_empresa_id': conviteEmpresaId,
  'convite_empresa_nome': conviteEmpresaNome,
  'convite_criado_em': origem == 'convite' ? '2026-07-18T09:00:00Z' : null,
  'empresa_id': empresaId,
  'empresa_nome': empresaNome,
});

PunhoEmpresa empresaPunho({
  String id = 'e1',
  String nome = 'Empresa do Convite',
  int limite = 3,
  int ativos = 1,
}) => PunhoEmpresa.fromJson({
  'id': id,
  'nome': nome,
  'limite_utilizadores': limite,
  'ativos_count': ativos,
});

/// Fake do repositório: guarda as decisões tomadas para as podermos verificar.
class FakePunhoAdmin extends PunhoAdminRepository {
  FakePunhoAdmin({
    this.porEstado = const {},
    this.empresas = const [],
    this.erro,
  });

  final Map<String, List<PunhoPedido>> porEstado;
  final List<PunhoEmpresa> empresas;
  final Object? erro;

  final decisoes = <Map<String, Object?>>[];
  final limitesDefinidos = <Map<String, Object?>>[];

  /// Quantas vezes o ecrã foi à base buscar a lista — é assim que se vê se um
  /// refresh aconteceu mesmo, e não só se o conteúdo mudou.
  int listagens = 0;

  @override
  Future<List<PunhoPedido>> listarPedidos({String estado = 'pendente'}) async {
    listagens++;
    if (erro != null) throw erro!;
    return porEstado[estado] ?? const [];
  }

  @override
  Future<List<PunhoEmpresa>> listarEmpresas() async {
    if (erro != null) throw erro!;
    return empresas;
  }

  @override
  Future<Map<String, dynamic>> decidir(
    String pedidoId,
    String decisao, {
    String? empresaId,
    int limiteUtilizadores = 1,
  }) async {
    decisoes.add({
      'pedido': pedidoId,
      'decisao': decisao,
      'empresa': empresaId,
      'limite': limiteUtilizadores,
    });
    return {
      'estado_novo': switch (decisao) {
        'aprovar' => 'aprovado',
        'recusar' => 'recusado',
        _ => 'revogado',
      },
      'empresa_id': empresaId,
      'membro_id': 'm-1',
    };
  }

  @override
  Future<Map<String, dynamic>> definirLimite(
    String empresaId,
    int novoLimite,
  ) async {
    if (erro != null) throw erro!;
    limitesDefinidos.add({'empresa': empresaId, 'limite': novoLimite});
    return {
      'empresa_id': empresaId,
      'limite_novo': novoLimite,
      'subscricao_id': 's-1',
    };
  }
}
