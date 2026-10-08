import 'package:flutter_test/flutter_test.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:washinvoice_control/core/contexto_instalacoes.dart';
import 'package:washinvoice_control/features/agora/agora_modelo.dart';

import '../acessos/punho/fake_punho_admin_repository.dart';
import 'agora_helpers.dart';

void main() {
  setUpAll(() => timeago.setLocaleMessages('pt', timeago.PtBrMessages()));

  final h = agoraAgora;

  test('ordem por urgência: expirada, acesso Fist, ajuda, terminal novo, '
      'renovação, a expirar, sugestão', () {
    final lics = [
      licencaTeste('1', validade: h.add(const Duration(days: 3))), // a expirar
      licencaTeste('2', validade: h.subtract(const Duration(days: 2))), // expirada
    ];
    final pings = [pingTeste('9')];
    final ctx = ContextoInstalacoes.build(
      clientes: const [],
      licencas: lics,
      pings: pings,
    );
    final itens = comporItensAgora(
      ctx: ctx,
      licencas: lics,
      pings: pings,
      machineIdsComLicenca: {for (final l in lics) l.machineId},
      ajuda: [ajudaTeste('a')],
      renovacoes: [renovacaoTeste('r')],
      sugestoes: [sugestaoTeste('s')],
      acessosFist: [pedidoFist()],
    );
    expect(itens.map((i) => i.tipo).toList(), [
      TipoAgora.expirada,
      TipoAgora.acessoFist,
      TipoAgora.ajuda,
      TipoAgora.terminalNovo,
      TipoAgora.renovacao,
      TipoAgora.aExpirar,
      TipoAgora.sugestao,
    ]);
  });

  test('dentro do tipo: mais antigo / mais próximo do prazo primeiro', () {
    final lics = [
      licencaTeste('1', validade: h.add(const Duration(days: 10))),
      licencaTeste('2', validade: h.add(const Duration(days: 2))),
      licencaTeste('3', validade: h.add(const Duration(days: 6))),
    ];
    final ajuda = [
      ajudaTeste('recente', quando: h.subtract(const Duration(minutes: 5))),
      ajudaTeste('antigo', quando: h.subtract(const Duration(days: 2))),
    ];
    final ctx = ContextoInstalacoes.build(
      clientes: const [],
      licencas: lics,
      pings: const [],
    );
    final itens = comporItensAgora(
      ctx: ctx,
      licencas: lics,
      pings: const [],
      machineIdsComLicenca: {for (final l in lics) l.machineId},
      ajuda: ajuda,
      renovacoes: const [],
      sugestoes: const [],
      acessosFist: const [],
    );
    expect(
      itens.where((i) => i.tipo == TipoAgora.aExpirar).map((i) => i.licenca!.id),
      ['2', '3', '1'],
    );
    expect(
      itens.where((i) => i.tipo == TipoAgora.ajuda).map((i) => i.pedidoAjuda!.id),
      ['antigo', 'recente'],
    );
  });

  test('pings de terminais com licença não são «terminal novo»; '
      'suspensas e activas fora do prazo não entram', () {
    final lics = [
      licencaTeste('1', validade: h.add(const Duration(days: 100))),
      licencaTeste(
        '2',
        validade: h.subtract(const Duration(days: 1)),
        activa: false, // suspensa: não é «expirada»
      ),
    ];
    final pings = [
      pingTeste('x', machineId: 'mid-1'), // já tem licença
      pingTeste('y'),
    ];
    final ctx = ContextoInstalacoes.build(
      clientes: const [],
      licencas: lics,
      pings: pings,
    );
    final itens = comporItensAgora(
      ctx: ctx,
      licencas: lics,
      pings: pings,
      machineIdsComLicenca: {for (final l in lics) l.machineId},
      ajuda: const [],
      renovacoes: const [],
      sugestoes: const [],
      acessosFist: const [],
    );
    expect(itens.map((i) => i.chave).toList(), ['terminalNovo:novo-y']);
  });

  test('subtítulo: expirou há…, expira em…', () {
    ItemAgora item(TipoAgora t, DateTime q) => ItemAgora(
      tipo: t,
      chave: 'k',
      app: 'pos',
      titulo: 't',
      quando: q,
    );
    expect(
      item(TipoAgora.expirada, h.subtract(const Duration(days: 3))).subtitulo(agora: h),
      startsWith('Expirou '),
    );
    expect(
      item(TipoAgora.aExpirar, h.add(const Duration(days: 3, hours: 1))).subtitulo(agora: h),
      startsWith('Expira em'),
    );
  });
}
