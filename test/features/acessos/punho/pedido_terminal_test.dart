import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/repositories/punho_admin_repository.dart';

/// **De que terminal veio o pedido.**
///
/// O WashInvoice sempre identificou um terminal pelo par `(machine_id, app)` —
/// é a chave de `licencas`. O pedido do Fist não a levava: nascia num trigger
/// sobre `auth.users`, que não sabe nada do aparelho. Resultado: um pedido era
/// só um email, e não havia como o cruzar com a instalação que aparecia na
/// lista ao lado.
///
/// Passou a levá-la a 5 de Agosto de 2026. Estes testes guardam o que o Control
/// mostra, incluindo o que mostra quando não sabe.
void main() {
  Map<String, dynamic> linha({
    String? machineId,
    String? maquinaNome,
    String? maquinaVersao,
    String? app,
  }) => {
    'id': 'p1',
    'user_id': 'u1',
    'nome': 'Ana Silva',
    'email': 'ana@exemplo.pt',
    'organizacao_indicada': 'Lavandaria Central',
    'perfil': 'gestor',
    'origem': 'livre',
    'estado': 'pendente',
    'criado_em': '2026-08-05T10:00:00Z',
    if (machineId != null) 'machine_id': machineId,
    if (maquinaNome != null) 'maquina_nome': maquinaNome,
    if (maquinaVersao != null) 'maquina_versao': maquinaVersao,
    if (app != null) 'app': app,
  };

  test('o nome legível da máquina ganha ao hash', () {
    // `M2101K6G` é o modelo do Redmi; `PC-LOJA` seria um Windows. Vem do
    // `info_host` que o terminal enviou no registo — o mesmo sítio de onde o
    // WashInvoice o tira.
    final p = FistPedido.fromJson(
      linha(machineId: 'a' * 64, maquinaNome: 'M2101K6G'),
    );

    expect(p.maquinaApresentavel, 'M2101K6G');
  });

  test('sem nome, o princípio do hash ainda distingue dois aparelhos', () {
    final p = FistPedido.fromJson(linha(machineId: '339ed1626af8fc47298'));

    expect(p.maquinaApresentavel, '339ed1626af8…');
  });

  test('sem terminal nenhum não se inventa um', () {
    // Acontece quando o aparelho não conseguiu ler o próprio identificador.
    // O cartão simplesmente não mostra a linha do terminal — melhor do que
    // mostrar uma máquina que ninguém sabe qual é.
    final p = FistPedido.fromJson(linha());

    expect(p.machineId, isNull);
    expect(p.maquinaApresentavel, isNull);
  });

  test('a app faz parte da chave e vem sempre', () {
    final p = FistPedido.fromJson(linha(machineId: 'abc'));

    expect(p.app, 'punho');
  });

  test('a versão do terminal vem do último ping', () {
    final p = FistPedido.fromJson(
      linha(machineId: 'abc', maquinaNome: 'M2101K6G', maquinaVersao: '0.3.1'),
    );

    expect(p.maquinaVersao, '0.3.1');
  });

  test('um nome em branco não conta como nome', () {
    // O `info_host` pode trazer a chave com valor vazio. Cair para o hash é
    // melhor do que mostrar um espaço onde devia estar o terminal.
    final p = FistPedido.fromJson(
      linha(machineId: 'abcdef0123456789', maquinaNome: '   '),
    );

    expect(p.maquinaApresentavel, 'abcdef012345…');
  });
}
