import '../models/cliente.dart';
import '../repositories/punho_admin_repository.dart';
import '../models/licenca.dart';
import '../models/ping.dart';
import 'apps_ui.dart';
import 'exibicao.dart';

/// Índice partilhado que cruza licenças, clientes e pings por `machine_id`/`nif`.
///
/// Construído uma vez a partir das listas carregadas e reutilizado por Dashboard,
/// Instalações, Pedidos de Ajuda e Mapa — evita cada ecrã reconstruir os mesmos
/// mapas e re-decidir como resolver nome/sinal/localidade (regra: um só sítio).
class ContextoInstalacoes {
  final Map<String, Cliente> _clientePorId;
  final Map<String, Cliente> _clientePorNif;
  final Map<String, Licenca> _licencaPorMachine;
  final Map<String, Ping> _pingPorMachine;
  final Map<String, (int ordem, int total)> _ordem;

  /// Nome da empresa por `machine_id`, vindo dos pedidos de acesso do Fist.
  /// Vazio nos ecrãs que não o carregam — aí a cascata segue como sempre.
  final Map<String, NomeDoTerminalFist> _nomesFist;

  ContextoInstalacoes._(
    this._clientePorId,
    this._clientePorNif,
    this._licencaPorMachine,
    this._pingPorMachine,
    this._ordem,
    this._nomesFist,
  );

  factory ContextoInstalacoes.build({
    required List<Cliente> clientes,
    required List<Licenca> licencas,
    required List<Ping> pings,
    Map<String, NomeDoTerminalFist> nomesFist = const {},
  }) {
    final porId = {for (final c in clientes) c.id: c};
    final porNif = {for (final c in clientes) c.nif: c};
    final licPorMachine = {for (final l in licencas) l.machineId: l};
    // pings já vêm reduzidos ao último por machine_id (ultimosPorInstalacao),
    // mas garantimos manter o mais recente caso venham repetidos.
    final pingPorMachine = <String, Ping>{};
    for (final p in pings) {
      final existente = pingPorMachine[p.machineId];
      if (existente == null || p.criadoEm.isAfter(existente.criadoEm)) {
        pingPorMachine[p.machineId] = p;
      }
    }
    return ContextoInstalacoes._(
      porId,
      porNif,
      licPorMachine,
      pingPorMachine,
      Exibicao.ordemTerminais(licencas),
      nomesFist,
    );
  }

  /// Os nomes que o Fist já sabe dos seus terminais (empresa aprovada ou o que
  /// o requerente declarou no pedido de acesso). **Falha em silêncio**: sem
  /// eles a cascata resolve-se na mesma (com o fallback «Fist · terminal xxxxxx»),
  /// e nenhum ecrã deixa de abrir por causa de um nome.
  static Future<Map<String, NomeDoTerminalFist>> carregarNomesFist(
    FistAdminRepository repo,
  ) => repo.nomesPorTerminal().catchError(
    (_) => <String, NomeDoTerminalFist>{},
  );

  Licenca? licencaDe(String machineId) => _licencaPorMachine[machineId];
  Ping? pingDe(String machineId) => _pingPorMachine[machineId];

  Cliente? clienteDe({String? clienteId, String? machineId, String? nif}) {
    if (clienteId != null && _clientePorId.containsKey(clienteId)) {
      return _clientePorId[clienteId];
    }
    if (machineId != null) {
      final lic = _licencaPorMachine[machineId];
      if (lic?.clienteId != null && _clientePorId.containsKey(lic!.clienteId)) {
        return _clientePorId[lic.clienteId];
      }
      if (lic?.nif != null && _clientePorNif.containsKey(lic!.nif)) {
        return _clientePorNif[lic.nif];
      }
    }
    if (nif != null) return _clientePorNif[nif];
    return null;
  }

  /// Ordem/total de terminais da licença de [machineId] (null se não aplicável).
  (int ordem, int total)? ordemDe(String machineId) {
    final lic = _licencaPorMachine[machineId];
    return lic == null ? null : _ordem[lic.id];
  }

  /// Nome a mostrar para uma instalação identificada por [machineId] (e [nif]
  /// como recurso).
  ///
  /// Cascata: nome **comercial** (do cliente ou da licença) → designação social
  /// (idem) (+ `· T<n>` se ≥2 terminais) → nome da máquina (`info_host`) →
  /// `NIF <x>` → `Sem NIF ainda`
  /// (mesma etiqueta que o card de Início de actividade, para o mesmo terminal
  /// aparecer igual em todo o lado). **Nunca** o machine_id (hash) — esse vive
  /// só na secção "Máquina" do DetalheCliente.
  String nomeDe({
    required String machineId,
    String? nif,

    /// `false` tira o « · T2» dos clientes com vários terminais — para a ficha,
    /// que já diz «Terminal 2 de 3» na linha por baixo.
    bool comTerminal = true,
  }) {
    final lic = _licencaPorMachine[machineId];
    final cliente = clienteDe(machineId: machineId, nif: nif);

    // Nome comercial primeiro — é por ele que se reconhece a loja; a
    // designação social é o nome legal e raramente é como se lhe chama.
    String? base;
    for (final candidato in [
      cliente?.nomeComercial,
      lic?.nomeComercial,
      cliente?.nome,
      lic?.nome,
    ]) {
      final v = candidato?.trim() ?? '';
      if (v.isNotEmpty) {
        base = v;
        break;
      }
    }

    if (base == null || base.isEmpty) {
      // Enquanto o POS não sincroniza a ficha da empresa, o nome da máquina
      // (ex.: `PC-LOJA`, do `info_host`) identifica melhor o terminal do que um
      // NIF que ainda pode ser o placeholder do auto-onboarding. O `machineId`
      // continua fora disto — é um hash, não serve para reconhecer nada.
      // O que o Fist já sabe sobre este terminal ganha ao modelo do aparelho.
      //
      // `M2101K6G` é um substituto para quando não se sabe nada. Assim que
      // alguém escreve o nome da empresa no pedido de acesso, sabe-se — e isso
      // acontece antes de haver NIF, ficha ou aprovação, porque o ecrã de pedir
      // acesso não pede NIF nenhum. Sai limpo: se o pedido ainda está pendente,
      // isso é um facto sobre o pedido e vive no ecrã de Pedidos Fist, não
      // colado ao nome numa lista onde ninguém decide nada.
      final doFist = _nomesFist[machineId];
      if (doFist != null) return doFist.paraMostrar;

      final host = lic?.hostname;
      if (host != null) return host;

      // Terminal do Fist sem nome nenhum que se saiba: nunca vazio e nunca só o
      // NIF (que no Fist é o placeholder do auto-onboarding). Os 6 primeiros
      // caracteres do `machine_id` distinguem um terminal de outro.
      final app = lic?.app ?? _pingPorMachine[machineId]?.app;
      if (app == AppsUi.punho) {
        final m = machineId.trim();
        return m.isEmpty
            ? 'Fist · terminal'
            : 'Fist · terminal ${m.length > 6 ? m.substring(0, 6) : m}';
      }

      final nifEfectivo = (nif != null && nif.trim().isNotEmpty)
          ? nif.trim()
          : (lic != null && lic.nif.trim().isNotEmpty ? lic.nif.trim() : null);
      // O placeholder do auto-onboarding não identifica ninguém — vale tanto
      // como não ter NIF nenhum.
      if (nifEfectivo != null && nifEfectivo != '000000000') {
        return 'NIF $nifEfectivo';
      }
      return 'Sem NIF ainda';
    }

    final o = lic == null ? null : _ordem[lic.id];
    if (comTerminal && o != null && o.$2 >= 2) return '$base · T${o.$1}';
    return base;
  }

  /// Linha "cidade do ping − localidade da loja" para [machineId].
  String sinalLocalidadeDe({required String machineId, String? nif}) {
    return Exibicao.sinalLocalidade(
      pingDe(machineId),
      clienteDe(machineId: machineId, nif: nif),
    );
  }
}
