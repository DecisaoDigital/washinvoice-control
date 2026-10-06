import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/licenca.dart';

/// Acesso a `licencas`.
///
/// Os métodos de leitura aceitam `app` opcional (`pos` / `punho`): vem do
/// `appFilterProvider`, e `null` significa "todas as apps" — não se aplica
/// filtro nenhum. Ver `docs/design/multi_app.md`.
class LicencasRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Licenca>> listar({String? app}) async {
    var q = _client.from('licencas').select();
    if (app != null) q = q.eq('app', app);
    final rows = await q.order('validade', ascending: true);
    return (rows as List)
        .map((e) => Licenca.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Licença de um terminal pelo seu [machineId] — a chave natural única por
  /// terminal. É o caminho de abertura do detalhe (uma instalação = um terminal
  /// = uma licença).
  ///
  /// Usa `maybeSingle()`: devolve `null` se não houver, e **lança** se houver
  /// mais do que uma linha com o mesmo `machine_id` (não devia acontecer). Esse
  /// erro é intencional — é reportado de forma visível na UI em vez de escolher
  /// silenciosamente uma das licenças.
  Future<Licenca?> porMachineId(String machineId) async {
    final row = await _client
        .from('licencas')
        .select()
        .eq('machine_id', machineId)
        .maybeSingle();
    if (row == null) return null;
    return Licenca.fromJson(row);
  }

  /// Todas as licenças de um NIF. Um NIF (cliente) pode ter **várias** licenças
  /// (um terminal cada), por isso devolve `List` — **não** usar para abrir o
  /// detalhe (usar [porMachineId]). Destinado a contextos de pesquisa.
  Future<List<Licenca>> porNif(String nif, {String? app}) async {
    var q = _client.from('licencas').select().eq('nif', nif);
    if (app != null) q = q.eq('app', app);
    final rows = await q;
    return (rows as List)
        .map((e) => Licenca.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Licenca>> aExpirar({int dias = 15, String? app}) async {
    final agora = DateTime.now();
    final limite = agora.add(Duration(days: dias));
    var q = _client
        .from('licencas')
        .select()
        .eq('activa', true)
        .gte('validade', agora.toIso8601String())
        .lte('validade', limite.toIso8601String());
    if (app != null) q = q.eq('app', app);
    final rows = await q.order('validade', ascending: true);
    return (rows as List)
        .map((e) => Licenca.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cria uma licença nova (id e created_em gerados pela base de dados).
  ///
  /// [userId] liga a licença ao utilizador Supabase Auth do terminal (POS).
  /// É o que o RLS usa para o POS ler só a SUA licença (`user_id = auth.uid()`).
  /// Fica `null` quando ainda não há utilizador criado — a licença fica órfã
  /// (o POS não a consegue ler) até ser reemitida com o `user_id` preenchido.
  ///
  /// [app] tem de ir sempre (`licencas.app` é `NOT NULL` sem default). Fica em
  /// `pos` por omissão porque é a única app cujas licenças o Cesar cria à mão
  /// aqui — o Fist auto-onboarda pela Edge Function `registar-terminal`.
  Future<void> criar({
    required String machineId,
    required String nif,
    String? nome,
    String? clienteId,
    required String plano,
    required DateTime validade,
    bool activa = true,
    bool oferta = false,
    String? userId,
    String app = 'pos',
  }) async {
    await _client.from('licencas').insert({
      'app': app,
      'machine_id': machineId,
      'nif': nif,
      'nome': nome,
      'cliente_id': clienteId,
      'plano': plano,
      'validade': validade.toIso8601String(),
      'activa': activa,
      'oferta': oferta,
      'user_id': userId,
    });
  }

  /// Lista os machine_id que já têm licença (para detetar instalações novas).
  Future<Set<String>> machineIdsComLicenca({String? app}) async {
    var q = _client.from('licencas').select('machine_id');
    if (app != null) q = q.eq('app', app);
    final rows = await q;
    return {
      for (final r in rows as List) (r as Map<String, dynamic>)['machine_id'] as String,
    };
  }

  /// **Colisão de série**: devolve uma licença **activa** com a mesma [serie]
  /// mas machine_id **diferente** de [excetoMachineId] (dois terminais a apontar
  /// para a mesma série — exactamente o que "série por terminal" evita), ou
  /// `null` se não houver. Usado ANTES de gerar um licenca.json com série.
  Future<Licenca?> licencaActivaComSerie(
    String serie, {
    required String excetoMachineId,
  }) async {
    final rows = await _client
        .from('licencas')
        .select()
        .eq('serie', serie)
        .eq('activa', true)
        .neq('machine_id', excetoMachineId);
    final lista = rows as List;
    if (lista.isEmpty) return null;
    return Licenca.fromJson(lista.first as Map<String, dynamic>);
  }

  /// Regista a série do terminal na licença (ao gerar o licenca.json).
  ///
  /// TODO: idealmente também passa a função dedicada, como as mutações de
  /// estado. Fica por migrar porque a série é um fluxo à parte (emissão do
  /// `licenca.json`), com as suas próprias regras de colisão.
  Future<void> definirSerie(String id, String serie) async {
    await _client.from('licencas').update({'serie': serie}).eq('id', id);
  }

  /// O que está pendurado nesta licença, antes de se perguntar se se apaga.
  ///
  /// Serve para a caixa de confirmação dizer números em vez de generalidades:
  /// numa licença do Fist vêm todos a zero, numa do POS pode vir cadeia
  /// fiscal. Ver `licenca_dependentes` no servidor.
  Future<Map<String, dynamic>> dependentes(String id) async {
    final resposta = await _client.rpc(
      'licenca_dependentes',
      params: {'p_licenca_id': id},
    );
    return (resposta as Map).cast<String, dynamic>();
  }

  /// Apaga a licença em definitivo.
  ///
  /// O servidor recusa a quem não for administrador global e recusa qualquer
  /// licença com guias comunicadas à AT — registo fiscal não se apaga por
  /// causa de uma limpeza de lista; para essas, desactivar é o caminho.
  Future<Map<String, dynamic>> apagar(String id) async {
    final resposta = await _client.rpc(
      'apagar_licenca',
      params: {'p_licenca_id': id},
    );
    return (resposta as Map).cast<String, dynamic>();
  }

  /// **Obsoleto** — usar `GerirLicencaService.suspender()` / `reactivar()`.
  ///
  /// Escrever aqui com a anon key deixa de funcionar quando a RLS de `licencas`
  /// fechar, e não regista **quem** fez a acção. Sem chamadores desde a ronda
  /// do painel de controlo remoto; mantido só para não partir código externo.
  @Deprecated('Usar GerirLicencaService.suspender()/reactivar()')
  Future<void> activar(String id, {required bool activa}) async {
    await _client.from('licencas').update({'activa': activa}).eq('id', id);
  }

  /// **Obsoleto** — usar as acções granulares de `GerirLicencaService`
  /// (`definirValidade`, `prolongar`, `mudarTier`, …).
  ///
  /// Mesmas razões de [activar]. Nota adicional: `toUpdateJson` não inclui
  /// `tier` nem `preferencias_features`, portanto esta via nunca os alterou.
  @Deprecated('Usar as acções de GerirLicencaService')
  Future<void> actualizar(Licenca l) async {
    // toUpdateJson exclui id/created_at/machine_id/user_id — só envia campos
    // mutáveis, evitando erros/drift ao actualizar (ex.: renovação).
    await _client.from('licencas').update(l.toUpdateJson()).eq('id', l.id);
  }
}
