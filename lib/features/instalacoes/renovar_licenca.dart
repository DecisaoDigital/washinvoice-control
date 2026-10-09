import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/dates.dart';
import '../../core/erros.dart';
import '../../models/licenca.dart';
import '../../models/pedido_renovacao.dart';
import '../../repositories/providers.dart';
import '../../services/registo_accoes.dart';

/// O que a bottom sheet de renovação oferece.
enum OpcaoRenovacao { dias30, meses3, ano1, outraData }

/// Nova validade para [opcao].
///
/// **Licença expirada: conta a partir de hoje**, não da validade antiga —
/// senão «+30 dias» a uma licença que caducou há dois meses dava uma licença
/// ainda expirada. Licença ainda válida (a expirar): soma-se à validade actual,
/// para quem renova antes do fim nunca perder dias.
///
/// [OpcaoRenovacao.outraData] não se calcula aqui (é escolhida à mão).
DateTime validadeRenovada(
  Licenca l,
  OpcaoRenovacao opcao, {
  DateTime? hoje,
}) {
  final agora = hoje ?? DateTime.now();
  final dia = DateTime(agora.year, agora.month, agora.day);
  final base = l.validade.isAfter(agora) ? l.validade : dia;
  final b = DateTime(base.year, base.month, base.day);
  return switch (opcao) {
    // Por componentes: somar `Duration(days:)` erra na mudança da hora.
    OpcaoRenovacao.dias30 => DateTime(b.year, b.month, b.day + 30),
    OpcaoRenovacao.meses3 => Dates.adicionarMeses(b, 3),
    OpcaoRenovacao.ano1 => Dates.adicionarMeses(b, 12),
    OpcaoRenovacao.outraData => throw ArgumentError('escolhida à mão'),
  };
}

/// «Renovar»: bottom sheet com +30 dias / +3 meses / +1 ano / Outra data.
///
/// Usa `gerir-licenca` (`definir_validade`), como o resto das mutações de
/// licença — fica auditado quem renovou. Depois mostra um SnackBar com
/// «Anular», que repõe a validade anterior (também com `definir_validade`).
/// [pedido], se houver, fica confirmado. [depois] corre no fim, para o ecrã
/// que chamou recarregar.
Future<void> renovarLicencaComSheet(
  BuildContext context,
  WidgetRef ref,
  Licenca l, {
  PedidoRenovacao? pedido,
  required String quem,
  Future<void> Function()? depois,
}) async {
  // Legado não é um plano atribuível: a folha parte de Base nesse caso.
  final tierInicial = l.tier == Tier.pro ? Tier.pro : Tier.base;
  var tierEscolhido = tierInicial;
  final escolha = await showModalBottomSheet<({OpcaoRenovacao opcao, Tier tier})>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text('Renovar $quem', style: AppText.h2),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Plano (atual: ${l.tier.rotulo})',
                      style: AppText.bodyStrong,
                    ),
                  ),
                  SegmentedButton<Tier>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: Tier.base, label: Text('Base')),
                      ButtonSegment(value: Tier.pro, label: Text('Pro')),
                    ],
                    selected: {tierEscolhido},
                    onSelectionChanged: (v) =>
                        setSt(() => tierEscolhido = v.first),
                  ),
                ],
              ),
            ),
            for (final o in OpcaoRenovacao.values)
              ListTile(
                minTileHeight: 56,
                leading: Icon(
                  o == OpcaoRenovacao.outraData
                      ? Icons.edit_calendar
                      : Icons.event_available,
                ),
                title: Text(_rotulo(o)),
                subtitle: o == OpcaoRenovacao.outraData
                    ? null
                    : Text('até ${Dates.data(validadeRenovada(l, o))}'),
                onTap: () =>
                    Navigator.pop(ctx, (opcao: o, tier: tierEscolhido)),
              ),
          ],
        ),
      ),
    ),
  );
  if (escolha == null || !context.mounted) return;

  DateTime nova;
  if (escolha.opcao == OpcaoRenovacao.outraData) {
    final agora = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: l.expirada ? agora.add(const Duration(days: 30)) : l.validade,
      firstDate: agora.subtract(const Duration(days: 1)),
      lastDate: agora.add(const Duration(days: 365 * 5)),
      helpText: 'Nova data de validade',
    );
    if (d == null) return;
    nova = d;
  } else {
    nova = validadeRenovada(l, escolha.opcao);
  }

  final anterior = l.validade;
  // Licença legada que se renova sem tocar no plano continua legada.
  final mudaPlano = escolha.tier != tierInicial;
  try {
    final servico = ref.read(gerirLicencaProvider);
    await servico.definirValidade(l.machineId, nova);
    if (mudaPlano) await servico.mudarTier(l.machineId, escolha.tier);
    if (pedido != null) await ref.read(pedidosRepoProvider).confirmar(pedido.id);
    final plano = (mudaPlano ? escolha.tier : l.tier).rotulo;
    await registarAccao(
      ref,
      tipo: pedido != null ? 'Pedido de renovação' : 'Licença',
      titulo: quem,
      app: l.app,
      machineId: l.machineId,
      pedido: pedido != null
          ? 'Pediu renovação (${pedido.planoDesejado})'
          : (l.expirada ? 'Licença expirada' : 'Licença a expirar'),
      accao: 'Renovada para $plano até ${Dates.data(nova)}',
    );
    messengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Licença renovada para $plano até ${Dates.data(nova)}'),
          duration: const Duration(seconds: 8),
          persist: false, // com acção, o SnackBar não fecha sozinho se não o disserem
          action: SnackBarAction(
            label: 'Anular',
            onPressed: () async {
              try {
                await servico.definirValidade(l.machineId, anterior);
                // Repõe também o plano, se a renovação o tinha mudado.
                if (mudaPlano && l.tier != Tier.legado) {
                  await servico.mudarTier(l.machineId, l.tier);
                }
                mostrarMensagem(
                  'Validade reposta: ${Dates.data(anterior)}.',
                );
              } catch (e, st) {
                mostrarErro(e, stack: st);
              }
              await depois?.call();
            },
          ),
        ),
      );
  } catch (e, st) {
    mostrarErro(e, stack: st);
  }
  await depois?.call();
}

String _rotulo(OpcaoRenovacao o) => switch (o) {
  OpcaoRenovacao.dias30 => '+30 dias',
  OpcaoRenovacao.meses3 => '+3 meses',
  OpcaoRenovacao.ano1 => '+1 ano',
  OpcaoRenovacao.outraData => 'Outra data',
};
