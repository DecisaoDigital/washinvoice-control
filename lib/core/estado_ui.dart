import 'package:flutter/material.dart';

import '../models/licenca.dart';
import 'app_colors.dart';

/// Helpers de apresentação para [EstadoLicenca].
extension EstadoLicencaUi on EstadoLicenca {
  Color get cor {
    switch (this) {
      case EstadoLicenca.activa:
        return AppColors.verde;
      case EstadoLicenca.aExpirar:
        return AppColors.laranja;
      case EstadoLicenca.expirada:
        return AppColors.vermelho;
      case EstadoLicenca.suspensa:
        return AppColors.textTertiary;
    }
  }

  /// Fundo pálido (tom 100) do estado — para pills e KPI cards.
  Color get corPastel {
    switch (this) {
      case EstadoLicenca.activa:
        return AppColors.verde100;
      case EstadoLicenca.aExpirar:
        return AppColors.laranja100;
      case EstadoLicenca.expirada:
        return AppColors.vermelho100;
      case EstadoLicenca.suspensa:
        return AppColors.fundo;
    }
  }

  /// Texto forte (tom 900) do estado — sobre [corPastel].
  Color get corForte {
    switch (this) {
      case EstadoLicenca.activa:
        return AppColors.verde900;
      case EstadoLicenca.aExpirar:
        return AppColors.laranja900;
      case EstadoLicenca.expirada:
        return AppColors.vermelho900;
      case EstadoLicenca.suspensa:
        return AppColors.textSecondary;
    }
  }

  String get rotulo {
    switch (this) {
      case EstadoLicenca.activa:
        return 'Activa';
      case EstadoLicenca.aExpirar:
        return 'A expirar';
      case EstadoLicenca.expirada:
        return 'Expirada';
      case EstadoLicenca.suspensa:
        return 'Suspensa';
    }
  }
}

/// Pequeno círculo colorido que indica o estado da licença.
class BadgeEstado extends StatelessWidget {
  final EstadoLicenca estado;
  final double tamanho;

  const BadgeEstado(this.estado, {super.key, this.tamanho = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: estado.cor,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Chip colorido com o rótulo do estado.
class ChipEstado extends StatelessWidget {
  final EstadoLicenca estado;

  const ChipEstado(this.estado, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: estado.cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: estado.cor.withValues(alpha: 0.4)),
      ),
      child: Text(
        estado.rotulo,
        style: TextStyle(
          color: estado.cor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
