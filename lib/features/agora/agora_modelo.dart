import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/app_colors.dart';
import '../../core/apps_ui.dart';
import '../../core/contexto_instalacoes.dart';
import '../../models/licenca.dart';
import '../../models/pedido_ajuda.dart';
import '../../models/pedido_renovacao.dart';
import '../../models/ping.dart';
import '../../models/sugestao.dart';
import '../../repositories/punho_admin_repository.dart';

/// O que pode estar à espera do Cesar na fila «Agora».
///
/// **A ordem dos valores É a prioridade**: o que vem primeiro passa à frente.
/// Um pedido aberto tem alguém à espera de resposta e vem antes de tudo; uma
/// licença expirada há muito não passa à frente de quem está a pedir ajuda.
enum TipoAgora {
  acessoFist,
  ajuda,
  terminalNovo,
  renovacao,
  expirada,
  aExpirar,
  sugestao;

  /// Etiqueta do cartão.
  String get etiqueta => switch (this) {
    expirada => 'Licença expirada',
    acessoFist => 'Pedido de acesso',
    ajuda => 'Pedido de ajuda',
    terminalNovo => 'Terminal novo',
    renovacao => 'Pedido de renovação',
    aExpirar => 'A expirar',
    sugestao => 'Sugestão',
  };

  /// Texto curto do chip de filtro.
  String get chip => switch (this) {
    expirada => 'Expiradas',
    acessoFist => 'Acessos Fist',
    ajuda => 'Ajuda',
    terminalNovo => 'Terminais novos',
    renovacao => 'Renovações',
    aExpirar => 'A expirar',
    sugestao => 'Sugestões',
  };

  IconData get icone => switch (this) {
    expirada => Icons.event_busy,
    acessoFist => Icons.how_to_reg_outlined,
    ajuda => Icons.help,
    terminalNovo => Icons.fiber_new_outlined,
    renovacao => Icons.autorenew,
    aExpirar => Icons.warning_amber_rounded,
    sugestao => Icons.lightbulb,
  };

  /// Cor de acento (tom 500) — as mesmas que o Resumo dá a estes assuntos.
  Color get cor => switch (this) {
    expirada => AppColors.vermelho500,
    acessoFist => AppColors.verde500,
    ajuda => AppColors.laranja500,
    terminalNovo => AppColors.azul500,
    renovacao => AppColors.roxo500,
    aExpirar => AppColors.laranja500,
    sugestao => AppColors.roxo500,
  };

  /// Tom 700 de [cor], para texto e botão (contraste).
  Color get corForte => switch (this) {
    expirada => AppColors.vermelho700,
    acessoFist => AppColors.verde700,
    ajuda => AppColors.laranja700,
    terminalNovo => AppColors.azul700,
    renovacao => AppColors.roxo700,
    aExpirar => AppColors.laranja700,
    sugestao => AppColors.roxo700,
  };
}

/// Uma linha da fila «Agora». Leva o objecto original do tipo respectivo para
/// o ecrã abrir o fluxo que já existe, sem voltar a procurar nada.
class ItemAgora {
  final TipoAgora tipo;

  /// Identificador estável (`<tipo>:<id>`), para chaves de widget e testes.
  final String chave;
  final String app;
  final String titulo;

  /// Data que ordena dentro do tipo: validade (expirada, a expirar) ou
  /// criação (todos os outros).
  final DateTime quando;

  /// Linha extra (notas do pedido, email, texto da sugestão), se houver.
  final String? detalhe;
  final String? machineId;
  final String? telefone;

  final Licenca? licenca;
  final Ping? ping;
  final PedidoAjuda? pedidoAjuda;
  final PedidoRenovacao? renovacao;
  final Sugestao? sugestao;
  final FistPedido? fistPedido;

  const ItemAgora({
    required this.tipo,
    required this.chave,
    required this.app,
    required this.titulo,
    required this.quando,
    this.detalhe,
    this.machineId,
    this.telefone,
    this.licenca,
    this.ping,
    this.pedidoAjuda,
    this.renovacao,
    this.sugestao,
    this.fistPedido,
  });

  /// «Expirou há 3 dias», «Expira em 5 dias», «há 2 horas».
  String subtitulo({DateTime? agora}) {
    final ref = agora ?? DateTime.now();
    switch (tipo) {
      case TipoAgora.expirada:
        return 'Expirou ${timeago.format(quando, locale: 'pt', clock: ref)}';
      case TipoAgora.aExpirar:
        return 'Expira ${timeago.format(quando, locale: 'pt', clock: ref, allowFromNow: true)}';
      default:
        return timeago.format(quando, locale: 'pt', clock: ref);
    }
  }
}

/// Junta o que os repositórios já devolvem numa só lista, ordenada por
/// urgência: primeiro pelo [TipoAgora], depois — dentro do tipo — o mais
/// antigo (ou o mais próximo do prazo) à frente.
///
/// É uma função pura de propósito: não consulta nada. As queries são as dos
/// ecrãs de origem (Resumo, Pedidos de ajuda, Sugestões, Pedidos Fist); aqui só
/// se compõe.
List<ItemAgora> comporItensAgora({
  required ContextoInstalacoes ctx,
  required List<Licenca> licencas,
  required List<Ping> pings,
  required Set<String> machineIdsComLicenca,
  required List<PedidoAjuda> ajuda,
  required List<PedidoRenovacao> renovacoes,
  required List<Sugestao> sugestoes,
  required List<FistPedido> acessosFist,
}) {
  final itens = <ItemAgora>[];

  for (final l in licencas) {
    final tipo = switch (l.estado) {
      EstadoLicenca.expirada => TipoAgora.expirada,
      EstadoLicenca.aExpirar => TipoAgora.aExpirar,
      _ => null,
    };
    if (tipo == null) continue;
    itens.add(
      ItemAgora(
        tipo: tipo,
        chave: '${tipo.name}:${l.id}',
        app: l.app,
        titulo: ctx.nomeDe(machineId: l.machineId, nif: l.nif),
        quando: l.validade,
        detalhe: l.planoLabel,
        machineId: l.machineId,
        licenca: l,
      ),
    );
  }

  for (final p in acessosFist) {
    itens.add(
      ItemAgora(
        tipo: TipoAgora.acessoFist,
        chave: 'acessoFist:${p.id}',
        app: AppsUi.punho,
        titulo: p.nomeApresentavel,
        quando: p.criadoEm,
        detalhe: p.email,
        machineId: p.machineId,
        fistPedido: p,
      ),
    );
  }

  for (final p in ajuda) {
    itens.add(
      ItemAgora(
        tipo: TipoAgora.ajuda,
        chave: 'ajuda:${p.id}',
        app: p.app,
        titulo: ctx.nomeDe(machineId: p.machineId, nif: p.nif),
        quando: p.criadoEm,
        detalhe: (p.notas?.trim().isEmpty ?? true) ? null : p.notas!.trim(),
        machineId: p.machineId,
        telefone: ctx
            .clienteDe(
              clienteId: p.clienteId,
              machineId: p.machineId,
              nif: p.nif,
            )
            ?.telemovel,
        pedidoAjuda: p,
      ),
    );
  }

  for (final p in pings) {
    if (machineIdsComLicenca.contains(p.machineId)) continue;
    itens.add(
      ItemAgora(
        tipo: TipoAgora.terminalNovo,
        chave: 'terminalNovo:${p.machineId}',
        app: p.app,
        titulo: ctx.nomeDe(machineId: p.machineId, nif: p.nif),
        quando: p.criadoEm,
        machineId: p.machineId,
        ping: p,
      ),
    );
  }

  for (final p in renovacoes) {
    itens.add(
      ItemAgora(
        tipo: TipoAgora.renovacao,
        chave: 'renovacao:${p.id}',
        app: p.app,
        titulo: ctx.nomeDe(machineId: p.machineId, nif: p.nif),
        quando: p.criadoEm,
        detalhe: 'Quer renovar: ${p.planoDesejado}',
        machineId: p.machineId,
        renovacao: p,
      ),
    );
  }

  for (final s in sugestoes) {
    final temCliente = s.machineId != null || s.nif != null;
    itens.add(
      ItemAgora(
        tipo: TipoAgora.sugestao,
        chave: 'sugestao:${s.id}',
        app: s.app,
        titulo: temCliente
            ? ctx.nomeDe(machineId: s.machineId ?? '', nif: s.nif)
            : 'Sugestão sem cliente associado',
        quando: s.criadoEm,
        detalhe: s.texto.trim().isEmpty ? null : s.texto.trim(),
        machineId: s.machineId,
        sugestao: s,
      ),
    );
  }

  return ordenarAgora(itens);
}

/// Ordena por urgência (ver [TipoAgora]) e, dentro do tipo, pela data mais
/// antiga primeiro. Estável: duas datas iguais mantêm a ordem de entrada.
List<ItemAgora> ordenarAgora(List<ItemAgora> itens) {
  final indexados = itens.indexed.toList()
    ..sort((a, b) {
      final porTipo = a.$2.tipo.index.compareTo(b.$2.tipo.index);
      if (porTipo != 0) return porTipo;
      final porData = a.$2.quando.compareTo(b.$2.quando);
      if (porData != 0) return porData;
      return a.$1.compareTo(b.$1);
    });
  return [for (final e in indexados) e.$2];
}

/// Quantos itens há de cada tipo.
Map<TipoAgora, int> contarPorTipo(Iterable<ItemAgora> itens) {
  final c = <TipoAgora, int>{};
  for (final i in itens) {
    c[i.tipo] = (c[i.tipo] ?? 0) + 1;
  }
  return c;
}
