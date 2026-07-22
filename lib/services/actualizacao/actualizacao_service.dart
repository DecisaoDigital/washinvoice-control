import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/actualizacao_info.dart';

/// Pergunta ao servidor se há build novo do Control.
///
/// Tudo passa pela Edge Function `versao-mais-recente`, que compara o
/// `build_number` local com a versão activa mais alta catalogada em
/// `versoes_apps`. Mesmo padrão injectável do [ComunicarSerieService]: o
/// construtor de produção liga-se ao Supabase e ao [PackageInfo]; o
/// [ActualizacaoService.comInvocador] deixa os testes correrem sem rede nem
/// plataforma.
class ActualizacaoService {
  /// Build local (o número depois do `+` no pubspec). Injectável porque
  /// `PackageInfo.fromPlatform()` não está disponível nos testes unitários.
  final Future<int> Function() _buildLocal;

  /// Invoca a function com o body já montado. Devolve o mapa da resposta, ou
  /// `null` se não houver sessão / resposta inesperada.
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic> body)
      _invocar;

  ActualizacaoService(SupabaseClient supabase)
      : _buildLocal = _buildLocalDoPackage,
        _invocar = ((body) async {
          // Precisa de sessão: a function tem verify_jwt e o token identifica o
          // caller. Sem sessão, não vale a pena sair à rede.
          final sessao = supabase.auth.currentSession;
          if (sessao == null) return null;

          final r = await supabase.functions
              .invoke(
                'versao-mais-recente',
                body: body,
                headers: {'Authorization': 'Bearer ${sessao.accessToken}'},
              )
              .timeout(const Duration(seconds: 10));

          final data = r.data;
          return data is Map<String, dynamic> ? data : null;
        });

  ActualizacaoService.comInvocador({
    required Future<int> Function() buildLocal,
    required Future<Map<String, dynamic>?> Function(Map<String, dynamic> body)
        invocar,
  })  : _buildLocal = buildLocal,
        _invocar = invocar;

  static Future<int> _buildLocalDoPackage() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// Devolve a [ActualizacaoInfo] se houver build novo, senão `null`. Nunca
  /// lança por causa de rede — deixa propagar só o inesperado (o chamador
  /// engole em silêncio: uma falha de verificação não deve chatear o admin).
  Future<ActualizacaoInfo?> verificar() async {
    final build = await _buildLocal();
    final data = await _invocar({
      'app': 'control',
      'build_number_local': build,
    });
    if (data == null) return null;
    if (data['actualizacao_disponivel'] != true) return null;
    return ActualizacaoInfo.fromJson(data);
  }
}
