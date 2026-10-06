import 'package:flutter_test/flutter_test.dart';
import 'package:washinvoice_control/features/nav/home_shell.dart';

/// **A barra de baixo e as páginas têm de ter o mesmo comprimento.**
///
/// O separador "Pedidos Fist" existia na lista de páginas e não na lista de
/// botões: cinco páginas, quatro botões. Ao entrar no Fist, `currentIndex`
/// valia 4 numa barra de 0..3 e o `BottomNavigationBar` atirava
/// `RangeError (length): Invalid value: Not in inclusive range 0..3: 4` de
/// dentro do `didUpdateWidget`, **a cada frame**.
///
/// O sintoma não parecia um crash: a app continuava pintada, com o pedido do
/// Fist à vista e o botão "Decidir" activo. Só não reagia a nada — nem ao
/// "Decidir", nem aos filtros, nem aos separadores. Visto no Redmi a 5/8/2026.
///
/// Por isso o teste é sobre o **invariante**, e não sobre o ecrã: é a
/// diferença de comprimentos que mata, e ela é verificável sem montar nada.
void main() {
  group('barra e páginas andam a par', () {
    test('como administrador global', () {
      expect(
        HomeShell.itensDe(true).length,
        HomeShell.paginasDe(true).length,
        reason: 'um índice válido para as páginas tem de o ser para a barra',
      );
    });

    test('como gerente de organização', () {
      expect(
        HomeShell.itensDe(false).length,
        HomeShell.paginasDe(false).length,
      );
    });

    test('o separador do Fist é exclusivo do admin', () {
      // As RPCs `punho_*_admin` recusam qualquer outra conta: mostrar o
      // separador a quem não pode entrar seria pô-lo a bater num erro.
      List<String?> rotulos(bool admin) =>
          HomeShell.itensDe(admin).map((i) => i.label).toList();

      expect(rotulos(true), contains('Pedidos Fist'));
      expect(rotulos(false), isNot(contains('Pedidos Fist')));
    });

    test('ao admin a barra passa dos quatro itens', () {
      // Marca a fronteira: a partir de cinco o `BottomNavigationBar` muda
      // sozinho para `shifting` (só o seleccionado mostra rótulo), e por isso
      // o `HomeShell` passa `type: BottomNavigationBarType.fixed`. Se um dia
      // alguém tirar o `type`, este número é o aviso de porque é que ele lá
      // estava.
      expect(HomeShell.itensDe(true).length, greaterThan(4));
      expect(HomeShell.itensDe(false).length, 4);
    });
  });
}
