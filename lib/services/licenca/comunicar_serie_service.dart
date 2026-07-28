import 'package:supabase_flutter/supabase_flutter.dart';

class ComunicarSerieException implements Exception {
  final String mensagem;
  const ComunicarSerieException(this.mensagem);

  @override
  String toString() => mensagem;
}

/// Comunicação de séries de facturação à AT, a partir do Control.
///
/// Tudo passa pela Edge Function `comunicar-serie`, que corre com service_role
/// depois de confirmar que o caller é admin (mesmo padrão de
/// [GerirLicencaService]). A function é a única que fala com a AT (mTLS +
/// WS-Security) e a única que decifra as credenciais AT do cliente — nunca
/// saem do servidor.
///
/// Duas acções:
///  - [guardarCredenciais]: grava o sub-utilizador AT do cliente (cifrado).
///  - [comunicar]: comunica uma série e devolve o ATCUD-CV.
class ComunicarSerieService {
  /// Invoca a function. Injectável para os testes não saírem à rede.
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> body)
      _invocar;

  ComunicarSerieService(SupabaseClient supabase)
      : _invocar = ((body) async {
          // Como no GerirLicencaService: o token do utilizador tem de ir
          // explicitamente para o `is_admin()` dentro da function saber QUEM
          // está a chamar (o auto-inject do supabase_flutter mete só a anon).
          final sessao = supabase.auth.currentSession;
          if (sessao == null) {
            throw const ComunicarSerieException(
              'sem sessão activa — inicia sessão de novo',
            );
          }
          final r = await supabase.functions
              .invoke(
                'comunicar-serie',
                body: body,
                headers: {'Authorization': 'Bearer ${sessao.accessToken}'},
              )
              // A comunicação à AT é síncrona e pode demorar (SOAP + mTLS).
              .timeout(const Duration(seconds: 30));
          final data = r.data;
          if (data is! Map<String, dynamic>) {
            throw const ComunicarSerieException(
                'resposta inesperada do servidor');
          }
          return data;
        });

  ComunicarSerieService.comInvocador(this._invocar);

  /// Tipos de documento oferecidos ao comunicar uma série.
  static const tiposDoc = ['FT', 'FR', 'FS', 'NC', 'ND'];

  /// Grava (cifradas) as credenciais do sub-utilizador AT deste cliente.
  /// Feito uma vez no setup; as credenciais nunca mais voltam a ser pedidas
  /// nem aparecem na UI.
  Future<void> guardarCredenciais(
    String machineId, {
    required String username,
    required String password,
  }) async {
    final data = await _invocar({
      'acao': 'guardar_credenciais',
      'machine_id': machineId,
      'at_username': username.trim(),
      'at_password': password,
    });
    if (data['ok'] != true) {
      throw ComunicarSerieException(
          data['erro'] as String? ?? 'falha ao guardar credenciais');
    }
  }

  /// Comunica uma série à AT e devolve o código de validação (ATCUD-CV).
  Future<String> comunicar(
    String machineId, {
    required String serie,
    required String tipoDoc,
    int numeroInicial = 1,
    DateTime? dataInicio,
    String meioProcessamento = 'OM',
  }) async {
    final data = await _invocar({
      'acao': 'comunicar',
      'machine_id': machineId,
      'serie': serie.trim(),
      'tipo_doc': tipoDoc,
      'numero_inicial': numeroInicial,
      'data_inicio': (dataInicio ?? DateTime.now())
          .toIso8601String()
          .substring(0, 10),
      'meio_processamento': meioProcessamento,
    });
    if (data['ok'] != true) {
      throw ComunicarSerieException(
          data['erro'] as String? ?? 'falha ao comunicar série');
    }
    final cod = data['codigo_validacao'];
    if (cod is! String || cod.trim().isEmpty) {
      throw const ComunicarSerieException(
          'a AT não devolveu código de validação');
    }
    return cod.trim();
  }
}
