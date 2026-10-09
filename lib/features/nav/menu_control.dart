import 'package:flutter/material.dart';

import '../acessos/gestao_acessos_screen.dart';
import '../sobre/sobre_screen.dart';

/// O menu ⋮ do canto superior direito: o que se usa pouco (contas com acesso ao
/// Control, Sobre e Terminar sessão). Substitui o antigo separador «Mais».
class MenuControl extends StatelessWidget {
  const MenuControl({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Menu',
      iconColor: Colors.white,
      icon: const Icon(Icons.more_vert),
      onSelected: (v) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              v == 0 ? const GestaoAcessosScreen() : const SobreScreen(),
        ),
      ),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 0, child: Text('Acessos (contas)')),
        PopupMenuItem(value: 1, child: Text('Sobre e terminar sessão')),
      ],
    );
  }
}
