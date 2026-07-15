import 'package:flutter/material.dart';

import '../app_radius.dart';
import '../estado_ui.dart';
import '../../models/licenca.dart';

/// Pill pequena com o estado da licença — fundo pastel (tom 100) + texto forte
/// (tom 900) do estado. Reforça o antigo `ChipEstado` com os tokens (tokens.md
/// §1.5 / §8).
class WiBadgeEstado extends StatelessWidget {
  final EstadoLicenca estado;

  const WiBadgeEstado(this.estado, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: estado.corPastel,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        estado.rotulo,
        style: TextStyle(
          color: estado.corForte,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
