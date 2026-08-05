import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/licenca.dart';

/// Retrato da licença depois de uma acção remota, tal como devolvido pela
/// Edge Function `gerir-licenca`.
class LicencaAtualizada {
  final bool activa;
  final DateTime validade;
  final Tier tier;
  final String plano;

  /// Chave mestre da empresa depois da acção. `null` nas licenças que ainda
  /// não a têm (todas as anteriores ao modelo do par).
  final String? chaveMestre;

  final Map<String, bool> preferenciasFeatures;

  const LicencaAtualizada({
    required this.activa,
    required this.validade,
    required this.tier,
    required this.plano,
    this.chaveMestre,
    this.preferenciasFeatures = const {},
  });

  factory LicencaAtualizada.fromJson(Map<String, dynamic> json) {
    final validade = json['validade'];
    if (validade is! String) {
      throw const GerirLicencaException('resposta sem validade');
    }
    return LicencaAtualizada(
      activa: json['activa'] as bool? ?? false,
      validade: DateTime.parse(validade),
      tier: TierInfo.parse(json['tier'] as String?),
      plano: json['plano'] as String? ?? '',
      chaveMestre: json['chave_mestre'] as String?,
      preferenciasFeatures: {
        for (final e in (json['preferencias_features'] as Map? ?? const {})
            .entries)
          if (e.key is String && e.value is bool)
            e.key as String: e.value as bool,
      },
    );
  }
}

class GerirLicencaException implements Exception {
  final String mensagem;
  const GerirLicencaException(this.mensagem);

  @override
  String toString() => mensagem;
}

/// Acções remotas sobre uma licença, a partir do Control.
///
/// Tudo passa pela Edge Function `gerir-licenca`, que corre com service_role
/// depois de confirmar que o caller é admin. Duas razões para não escrever
/// directamente na tabela:
///
/// 1. No dia em que a RLS de `licencas` fechar, isto continua a funcionar sem
///    alterações de código;
/// 2. A function regista em `licencas_audit` **quem** fez a acção — o trigger
///    sozinho não consegue (escritas com service_role não têm `auth.uid()`).
class GerirLicencaService {
  /// Invoca a function. Injectável para testes não saírem à rede.
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> body)
      _invocar;

  GerirLicencaService(SupabaseClient supabase)
      : _invocar = ((body) async {
          // O supabase_flutter auto-injecta a ANON key no `Authorization` do
          // `functions.invoke`. Isso faz `verify_jwt: true` passar mas `getUser()`
          // dentro da function não sabe QUEM está a chamar — o auth do
          // utilizador tem de ser passado explicitamente aqui.
          final sessao = supabase.auth.currentSession;
          if (sessao == null) {
            throw const GerirLicencaException(
              'sem sessão activa — inicia sessão de novo',
            );
          }
          final r = await supabase.functions
              .invoke(
                'gerir-licenca',
                body: body,
                headers: {
                  'Authorization': 'Bearer ${sessao.accessToken}',
                },
              )
              .timeout(const Duration(seconds: 15));
          final data = r.data;
          if (data is! Map<String, dynamic>) {
            throw const GerirLicencaException('resposta inesperada do servidor');
          }
          return data;
        });

  GerirLicencaService.comInvocador(this._invocar);

  /// Dias aceites pela function. Qualquer outro valor é rejeitado com 400.
  static const diasPermitidos = [5, 15, 30];

  Future<LicencaAtualizada> prolongar(String machineId, int dias) =>
      _acao('prolongar', machineId, {'dias': dias});

  /// Dar tempo a uma licença — e o que "dar 5 dias" quer dizer depende de que
  /// licença é.
  ///
  /// **Trial do Punho**: o número é uma *janela a contar de hoje*. "5 dias"
  /// quer dizer que caduca daqui a cinco, mesmo que encurte o que lá estava.
  /// É a regra do César, 5/8/2026 — ver [Licenca.diasContamDeHoje].
  ///
  /// **Tudo o resto** — POS inteiro, trials incluídos, e qualquer licença paga
  /// em qualquer app: o número é um *acréscimo*. Soma-se à validade actual e
  /// nunca encurta.
  ///
  /// Nota: no caso do trial isto passa por `definir_validade`, que também
  /// reactiva. Dar dias a um trial suspenso volta a pô-lo a andar — que é o
  /// que se quer de quem lhe está a dar tempo, mas convém estar escrito.
  Future<LicencaAtualizada> darDias(Licenca licenca, int dias) {
    if (!licenca.diasContamDeHoje) return prolongar(licenca.machineId, dias);
    final agora = DateTime.now();
    // Construída por componentes para o dia rolar mês/ano em condições; somar
    // `Duration(days:)` a um `DateTime` local erra na mudança da hora.
    final ate = DateTime(agora.year, agora.month, agora.day + dias);
    return definirValidade(licenca.machineId, ate);
  }

  /// Define uma validade escolhida à mão (renovação após pagamento) e reactiva
  /// a licença. Use-se [prolongar] para os incrementos rápidos de 5/15/30 dias.
  Future<LicencaAtualizada> definirValidade(String machineId, DateTime data) =>
      _acao('definir_validade', machineId, {
        'validade': data.toIso8601String().substring(0, 10),
      });

  Future<LicencaAtualizada> suspender(String machineId) =>
      _acao('suspender', machineId, const {});

  Future<LicencaAtualizada> reactivar(String machineId) =>
      _acao('reactivar', machineId, const {});

  Future<LicencaAtualizada> cancelar(String machineId) =>
      _acao('cancelar', machineId, const {});

  /// Muda o **nível comercial**. Não mexe em `plano` (duração), que faz parte
  /// da assinatura HMAC do `licenca.json` instalado no terminal.
  Future<LicencaAtualizada> mudarTier(String machineId, Tier tier) {
    if (tier == Tier.legado) {
      throw const GerirLicencaException('legado não é um tier atribuível');
    }
    return _acao('mudar_tier', machineId, {'tier': tier.name});
  }

  /// Garante que este terminal tem a **chave mestre da empresa** e devolve-a.
  ///
  /// Idempotente e partilhada: a primeira chamada de um NIF cria a chave, todas
  /// as seguintes — deste terminal ou de qualquer outro da mesma empresa —
  /// devolvem a mesma. É assim que o segundo terminal entra na empresa que já
  /// existe em vez de fundar uma nova.
  ///
  /// ⚠️ A chave entra na base assinada do `licenca.json`. Chamar isto **sem**
  /// gerar e instalar o ficheiro novo a seguir deixa a base de dados e o
  /// terminal a dizer coisas diferentes.
  Future<LicencaAtualizada> atribuirChaveMestre(String machineId,
          {String? prefixo}) =>
      _acao('atribuir_chave_mestre', machineId, {
        if (prefixo != null && prefixo.isNotEmpty) 'prefixo': prefixo,
      });

  Future<LicencaAtualizada> _acao(
    String acao,
    String machineId,
    Map<String, dynamic> parametros,
  ) async {
    final data = await _invocar({
      'acao': acao,
      'machine_id': machineId,
      'parametros': parametros,
    });
    if (data['ok'] != true) {
      throw GerirLicencaException(
          data['erro'] as String? ?? 'falha desconhecida');
    }
    final licenca = data['licenca_actualizada'];
    if (licenca is! Map<String, dynamic>) {
      throw const GerirLicencaException('resposta sem licenca_actualizada');
    }
    return LicencaAtualizada.fromJson(licenca);
  }
}
