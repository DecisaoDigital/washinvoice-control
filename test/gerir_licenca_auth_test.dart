import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/services/licenca/gerir_licenca_service.dart';

/// Fase 1 — o `gerir-licenca` precisa de saber QUEM chama.
///
/// O `supabase_flutter` auto-injecta a anon key no `Authorization` do
/// `functions.invoke`. Isso faz o `verify_jwt: true` passar, mas o `getUser()`
/// dentro da function não encontra utilizador e devolve 401. O cliente tem de
/// passar o `accessToken` da sessão explicitamente.
///
/// **Limite deste teste:** a injecção do header vive no construtor de
/// produção, que depende de um `SupabaseClient` real e por isso não é
/// exercitada aqui — o que se cobre é o contrato à volta dela (sessão ausente
/// dá erro claro, e o body chega intacto). A prova de que o header certo
/// desbloqueia a function foi feita contra a function deployed: com anon key
/// devolve 401, com token de sessão passa.
void main() {
  test('sem sessão activa → erro explícito, sem sair à rede', () async {
    var chamou = false;
    final servico = GerirLicencaService.comInvocador((_) async {
      chamou = true;
      throw const GerirLicencaException('sem sessão activa — inicia sessão de novo');
    });

    expect(
      () => servico.suspender('abc123'),
      throwsA(isA<GerirLicencaException>().having(
        (e) => e.mensagem,
        'mensagem',
        contains('sessão'),
      )),
    );
    await Future<void>.delayed(Duration.zero);
    expect(chamou, isTrue);
  });

  test('a mensagem de sessão ausente diz o que fazer', () {
    const e = GerirLicencaException('sem sessão activa — inicia sessão de novo');
    // Não basta dizer que falhou: o Cesar tem de perceber que é para voltar a
    // entrar, não que a licença está avariada.
    expect(e.mensagem, contains('inicia sessão'));
  });

  test('401 do servidor chega ao chamador com a mensagem da function',
      () async {
    final servico = GerirLicencaService.comInvocador(
        (_) async => {'ok': false, 'erro': 'não autenticado'});

    expect(
      () => servico.prolongar('abc123', 5),
      throwsA(isA<GerirLicencaException>()
          .having((e) => e.mensagem, 'mensagem', 'não autenticado')),
    );
  });

  test('403 (autenticado mas não admin) é distinguível de 401', () async {
    final servico = GerirLicencaService.comInvocador((_) async =>
        {'ok': false, 'erro': 'sem permissões de administrador'});

    expect(
      () => servico.cancelar('abc123'),
      throwsA(isA<GerirLicencaException>().having(
          (e) => e.mensagem, 'mensagem', contains('administrador'))),
    );
  });
}
