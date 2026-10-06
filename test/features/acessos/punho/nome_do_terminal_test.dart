import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/core/contexto_instalacoes.dart';
import 'package:washinvoice_control/models/licenca.dart';
import 'package:washinvoice_control/repositories/punho_admin_repository.dart';

/// **O modelo do aparelho só se mostra quando não se sabe mais nada.**
///
/// `M2101K6G` é um substituto. Deixa de o ser assim que alguém escreve o nome
/// da empresa no pedido de acesso — e isso acontece antes de haver NIF, ficha
/// ou aprovação, porque o ecrã de pedir acesso não pede NIF nenhum. O Control
/// continuava a chamar-lhe pelo modelo muito depois de já saber "DepilConcept".
void main() {
  const maquina = '07c6da016e084a96619bb4401f00cbe6eaf1fc6c2f5c568dc30dd3bc32acdbea';

  Licenca licenca({String nome = '', String nif = '000000000'}) => Licenca(
    id: 'l1',
    machineId: maquina,
    nif: nif,
    nome: nome,
    plano: 'trial',
    validade: DateTime(2026, 8, 10),
    activa: true,
    criadoEm: DateTime(2026, 8, 5),
    app: 'punho',
    infoHost: const {'hostname': 'M2101K6G'},
  );

  ContextoInstalacoes ctx({
    Map<String, NomeDoTerminalFist> nomes = const {},
    Licenca? lic,
  }) => ContextoInstalacoes.build(
    clientes: const [],
    licencas: [lic ?? licenca()],
    pings: const [],
    nomesFist: nomes,
  );

  test('sem nada sabido, o modelo do aparelho ainda serve', () {
    expect(ctx().nomeDe(machineId: maquina), 'M2101K6G');
  });

  test('um pedido aprovado dá o nome da empresa, limpo', () {
    final c = ctx(
      nomes: {
        maquina: const NomeDoTerminalFist(
          nome: 'DepilConcept',
          aprovado: true,
        ),
      },
    );

    expect(c.nomeDe(machineId: maquina), 'DepilConcept');
  });

  test('um pedido por aprovar mostra o nome limpo, sem etiqueta', () {
    // Chegou a sair `DepilConcept (por aprovar)`. Duas coisas erradas: o que
    // está por aprovar é o pedido, não o nome; e a etiqueta contradizia o
    // Control, onde este terminal já tinha trial atribuído. Quem decide sobre
    // o pedido decide-o no ecrã dos pedidos, não numa lista de instalações.
    final c = ctx(
      nomes: {
        maquina: const NomeDoTerminalFist(
          nome: 'DepilConcept',
          aprovado: false,
        ),
      },
    );

    expect(c.nomeDe(machineId: maquina), 'DepilConcept');
  });

  test('aprovado continua a distinguir a ficha da declaração', () {
    // O sinal não desapareceu, só deixou de ser decoração: é ele que faz a
    // RPC preferir o nome de `punho_empresas` ao que o requerente escreveu.
    const declarado = NomeDoTerminalFist(nome: 'X', aprovado: false);
    const confirmado = NomeDoTerminalFist(nome: 'X', aprovado: true);

    expect(declarado.aprovado, isFalse);
    expect(confirmado.aprovado, isTrue);
    expect(declarado.paraMostrar, confirmado.paraMostrar);
  });

  test('a ficha sincronizada continua a mandar sobre o pedido', () {
    // Quando a licença já tem nome verdadeiro, ele ganha — é a fonte mais
    // forte, e o pedido não a substitui.
    final c = ctx(
      lic: licenca(nome: 'DepilConcept Braga', nif: '509442129'),
      nomes: {
        maquina: const NomeDoTerminalFist(
          nome: 'DepilConcept',
          aprovado: true,
        ),
      },
    );

    expect(c.nomeDe(machineId: maquina), 'DepilConcept Braga');
  });

  test('um terminal sem pedido nenhum não herda o nome de outro', () {
    final c = ctx(
      nomes: {
        'outra-maquina': const NomeDoTerminalFist(
          nome: 'DepilConcept',
          aprovado: true,
        ),
      },
    );

    expect(c.nomeDe(machineId: maquina), 'M2101K6G');
  });
}
