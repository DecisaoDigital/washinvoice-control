import 'package:flutter/material.dart';

import '../models/cliente.dart';
import '../models/licenca.dart';
import '../models/ping.dart';
import 'app_colors.dart';
import 'localidades.dart';

/// Regras de exibição partilhadas entre ecrãs (redesign v1.4, Fase 5).
///
/// Fonte única para: nome a mostrar de uma licença, linha "Sinal − Localidade",
/// e o ícone/cor do método de geolocalização do ping.
class Exibicao {
  Exibicao._();

  /// Nome a mostrar de uma licença.
  ///
  /// - Sem múltiplos terminais (`totalTerminaisCliente == null` ou `<= 1`):
  ///   só o nome (ou `NIF <nif>` se a licença não tiver nome).
  /// - Com 2+ terminais do mesmo cliente: `<nome> · T<ordem>`.
  static String nomeExibicao(
    Licenca l, {
    int? ordemTerminal,
    int? totalTerminaisCliente,
  }) {
    final base = (l.nome != null && l.nome!.trim().isNotEmpty)
        ? l.nome!.trim()
        : (l.nif.trim().isNotEmpty
            ? 'NIF ${l.nif.trim()}'
            : 'Terminal sem identificação');
    if (totalTerminaisCliente == null || totalTerminaisCliente <= 1) {
      return base;
    }
    return '$base · T${ordemTerminal ?? '?'}';
  }

  /// Linha "Sinal − Localidade": cidade automática do ping (o que o sinal diz)
  /// à esquerda, localidade humana da loja à direita.
  static String sinalLocalidade(Ping? p, Cliente? c) {
    final cidade = Localidades.traduzir(p?.cidade);
    final sinal = cidade.isEmpty ? '?' : cidade;
    final loja = (c?.localidade != null && c!.localidade!.trim().isNotEmpty)
        ? c.localidade!.trim()
        : '-';
    return '$sinal − $loja';
  }

  /// Ícone do método de geolocalização do ping.
  static IconData iconeSinal(String? metodoGeo) {
    switch (metodoGeo) {
      case 'gps':
        return Icons.gps_fixed;
      case 'ip':
        return Icons.wifi;
      case 'nenhum':
      default:
        // null (pings antigos sem metodo_geo) trata-se como "nenhum".
        return Icons.signal_wifi_off_outlined;
    }
  }

  /// Cor do método de geolocalização.
  ///
  /// Nota de reconciliação: o prompt pedia `verde600`; o `tokens.md` só define
  /// 500/700, por isso usa-se `verde700` (o token mais próximo) — nada de valor
  /// mágico fora da escala.
  static Color corSinal(String? metodoGeo) {
    switch (metodoGeo) {
      case 'gps':
        return AppColors.verde700;
      case 'ip':
        return AppColors.laranja700;
      case 'nenhum':
      default:
        return AppColors.textTertiary;
    }
  }

  /// Descrição humana do método de geolocalização (para o card de detalhe).
  static String descricaoSinal(String? metodoGeo) {
    switch (metodoGeo) {
      case 'gps':
        return 'GPS';
      case 'ip':
        return 'Fornecedor de internet';
      case 'nenhum':
      default:
        // null trata-se como "nenhum".
        return 'Sem sinal';
    }
  }

  /// Ordem (1..N) e total de terminais por licença, agrupando por `cliente_id`
  /// e ordenando por `created_at` ascendente. Licenças sem cliente contam como
  /// terminal único (ordem 1, total 1).
  ///
  /// Devolve `Map<licencaId, (ordem, total)>` reutilizável entre ecrãs.
  static Map<String, (int ordem, int total)> ordemTerminais(
    List<Licenca> licencas,
  ) {
    final porCliente = <String, List<Licenca>>{};
    final resultado = <String, (int, int)>{};

    for (final l in licencas) {
      if (l.clienteId == null) {
        resultado[l.id] = (1, 1);
      } else {
        porCliente.putIfAbsent(l.clienteId!, () => []).add(l);
      }
    }

    for (final grupo in porCliente.values) {
      grupo.sort((a, b) => a.criadoEm.compareTo(b.criadoEm));
      final total = grupo.length;
      for (var i = 0; i < total; i++) {
        resultado[grupo[i].id] = (i + 1, total);
      }
    }

    return resultado;
  }
}
