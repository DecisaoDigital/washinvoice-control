import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Estado de uma versão face à mais evoluída encontrada no conjunto.
enum EstadoVersao { atual, anterior, antiga, desconhecida }

extension EstadoVersaoUi on EstadoVersao {
  Color get cor {
    switch (this) {
      case EstadoVersao.atual:
        return AppColors.verde;
      case EstadoVersao.anterior:
        return AppColors.laranja;
      case EstadoVersao.antiga:
        return AppColors.vermelho;
      case EstadoVersao.desconhecida:
        return AppColors.textTertiary;
    }
  }
}

/// Compara duas versões no formato "1.4", "1.10.2", etc.
/// Devolve negativo se a < b, 0 se iguais, positivo se a > b.
int compararVersao(String a, String b) {
  final pa = a.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  final pb = b.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}

/// Classifica versões tendo como referência a mais evoluída presente no
/// conjunto. A versão mais alta é a "atual" (verde); a segunda mais alta
/// presente é a "anterior" (laranja); todas as restantes são "antigas"
/// (vermelho). Versões em falta são "desconhecidas" (cinza).
class ClassificadorVersoes {
  late final List<String> _distintasDesc;

  ClassificadorVersoes(Iterable<String?> versoes) {
    final set = <String>{};
    for (final v in versoes) {
      if (v != null && v.trim().isNotEmpty) set.add(v.trim());
    }
    _distintasDesc = set.toList()..sort((a, b) => compararVersao(b, a));
  }

  /// A versão de referência (a mais evoluída encontrada), ou null se nenhuma.
  String? get versaoAtual =>
      _distintasDesc.isNotEmpty ? _distintasDesc.first : null;

  EstadoVersao estadoDe(String? versao) {
    if (versao == null || versao.trim().isEmpty) {
      return EstadoVersao.desconhecida;
    }
    if (_distintasDesc.isEmpty) return EstadoVersao.desconhecida;
    final v = versao.trim();
    if (compararVersao(v, _distintasDesc[0]) == 0) return EstadoVersao.atual;
    if (_distintasDesc.length > 1 &&
        compararVersao(v, _distintasDesc[1]) == 0) {
      return EstadoVersao.anterior;
    }
    return EstadoVersao.antiga;
  }
}

/// Pequena "pílula" colorida com a versão (ex.: v1.4), tingida pelo estado.
class VersaoBadge extends StatelessWidget {
  final String? versao;
  final EstadoVersao estado;

  const VersaoBadge({super.key, required this.versao, required this.estado});

  @override
  Widget build(BuildContext context) {
    final cor = estado.cor;
    final texto = (versao == null || versao!.trim().isEmpty)
        ? 'v?'
        : 'v${versao!.trim()}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          color: cor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
