import '../models/cliente.dart';
import '../models/licenca.dart';
import '../models/ping.dart';
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

  ContextoInstalacoes._(
    this._clientePorId,
    this._clientePorNif,
    this._licencaPorMachine,
    this._pingPorMachine,
    this._ordem,
  );

  factory ContextoInstalacoes.build({
    required List<Cliente> clientes,
    required List<Licenca> licencas,
    required List<Ping> pings,
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
    );
  }

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
  /// como recurso). Usa a licença + ordem de terminal quando existe.
  String nomeDe({required String machineId, String? nif}) {
    final lic = _licencaPorMachine[machineId];
    if (lic != null) {
      final o = _ordem[lic.id];
      return Exibicao.nomeExibicao(
        lic,
        ordemTerminal: o?.$1,
        totalTerminaisCliente: o?.$2,
      );
    }
    final c = clienteDe(nif: nif);
    if (c != null) return c.nome;
    if (nif != null && nif.trim().isNotEmpty) return 'NIF ${nif.trim()}';
    // Nunca mostrar o machine_id (hash) como identificador em listas — vive só
    // na secção "Máquina" do DetalheCliente (monospace + copiar).
    return 'Terminal sem identificação';
  }

  /// Linha "cidade do ping − localidade da loja" para [machineId].
  String sinalLocalidadeDe({required String machineId, String? nif}) {
    return Exibicao.sinalLocalidade(
      pingDe(machineId),
      clienteDe(machineId: machineId, nif: nif),
    );
  }
}
