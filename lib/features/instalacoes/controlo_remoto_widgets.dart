import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import '../../core/app_theme.dart';
import '../../core/dates.dart';
import '../../core/widgets/wi_card.dart';
import '../../models/licenca.dart';
import '../../repositories/audit_licencas_repository.dart';
import '../../services/licenca/gerir_licenca_service.dart';

/// Cabeçalho de card (ícone + título), igual ao usado no detalhe do cliente.
class _Header extends StatelessWidget {
  final IconData icone;
  final String titulo;
  const _Header({required this.icone, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icone, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(titulo, style: AppText.h2),
        ],
      ),
    );
  }
}

/// Acções remotas sobre a licença de um terminal.
///
/// Tudo passa pela Edge Function `gerir-licenca`. Os botões ficam travados em
/// bloco enquanto uma acção decorre — evita o duplo-clique que prolongaria
/// 10 dias em vez de 5.
class CardControloRemoto extends StatelessWidget {
  final Licenca licenca;
  final bool ocupado;
  /// Dar tempo à licença. Chamava-se `onProlongar` enquanto dar tempo era
  /// sempre somar; num trial passou a ser uma janela a contar de hoje, e o
  /// nome antigo mentia. Ver [GerirLicencaService.darDias].
  final void Function(int dias) onDarDias;
  final VoidCallback onSuspender;
  final VoidCallback onReactivar;
  final VoidCallback onCancelar;
  final void Function(Tier) onMudarTier;
  final VoidCallback onVerHistorial;

  const CardControloRemoto({
    super.key,
    required this.licenca,
    required this.ocupado,
    required this.onDarDias,
    required this.onSuspender,
    required this.onReactivar,
    required this.onCancelar,
    required this.onMudarTier,
    required this.onVerHistorial,
  });

  @override
  Widget build(BuildContext context) {
    final l = licenca;
    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(
              icone: Icons.settings_remote, titulo: 'Controlo remoto'),
          if (ocupado) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text('Validade e estado', style: AppText.caption),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final dias in GerirLicencaService.diasPermitidos)
                OutlinedButton(
                  onPressed: ocupado ? null : () => onDarDias(dias),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.azul700),
                  // Sem `+` no trial: ali o número é a janela toda, a contar
                  // de hoje, e o sinal de mais prometia uma soma que não
                  // acontece. Numa licença paga é mesmo uma soma.
                  child: Text(l.diasContamDeHoje ? '$dias dias' : '+$dias dias'),
                ),
              if (l.activa)
                OutlinedButton.icon(
                  onPressed: ocupado ? null : onSuspender,
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('Suspender'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.vermelho),
                )
              else
                OutlinedButton.icon(
                  onPressed: ocupado ? null : onReactivar,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Reactivar'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.verde),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Text('Plano', style: AppText.caption),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              ChipTier(tier: l.tier),
              const SizedBox(width: AppSpacing.md),
              if (l.tier == Tier.pro)
                OutlinedButton(
                  onPressed: ocupado ? null : () => onMudarTier(Tier.base),
                  child: const Text('Mudar para Base'),
                )
              else
                OutlinedButton(
                  onPressed: ocupado ? null : () => onMudarTier(Tier.pro),
                  child: const Text('Mudar para Pro'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: onVerHistorial,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Ver historial'),
              ),
              TextButton(
                onPressed: ocupado ? null : onCancelar,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.vermelho,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Cancelar licença'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip do nível comercial: Pro dourado, Base cinza, Legado só contornado
/// (não é um nível atribuível — é uma licença anterior ao modelo Base/Pro).
class ChipTier extends StatelessWidget {
  final Tier tier;
  const ChipTier({super.key, required this.tier});

  static const _dourado = Color(0xFFD4A017);
  static const _cinza = Color(0xFFE5E5E5);

  @override
  Widget build(BuildContext context) {
    final (Color? fundo, Color texto, Color? borda) = switch (tier) {
      Tier.pro => (_dourado, Colors.white, null),
      Tier.base => (_cinza, AppColors.textSecondary, null),
      Tier.legado => (null, AppColors.textSecondary, AppColors.textTertiary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: borda == null ? null : Border.all(color: borda),
      ),
      child: Text(
        tier.rotulo,
        style:
            TextStyle(color: texto, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

/// Preferências de features do admin do POS — **read-only**.
///
/// Quem as altera é o admin no POS. O estado mostrado combina tier e
/// preferência (mesma regra do `featureVisivel` do POS): num terminal Base
/// aparece tudo desligado, independentemente do que esteja no JSONB.
class CardPreferencias extends StatelessWidget {
  final Licenca licenca;
  const CardPreferencias({super.key, required this.licenca});

  static const features = [
    ('guias', 'Guias de Transporte'),
    ('gestao', 'Gestão'),
    ('graficos', 'Gráficos'),
  ];

  @override
  Widget build(BuildContext context) {
    return WiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(icone: Icons.tune, titulo: 'Preferências do admin'),
          for (final (chave, rotulo) in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    licenca.featureVisivel(chave)
                        ? Icons.check_circle
                        : Icons.remove_circle_outline,
                    size: 18,
                    color: licenca.featureVisivel(chave)
                        ? AppColors.verde
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(rotulo, style: AppText.body),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            licenca.tier.temExtras
                ? 'As preferências são controladas pelo admin no POS. Se '
                    'quiseres mudar alguma, contacta o cliente.'
                : 'Terminal em plano Base — as funcionalidades extra estão '
                    'indisponíveis, independentemente das preferências guardadas.',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

/// Historial de acções remotas sobre esta licença (`licencas_audit`).
class ModalHistorial extends StatelessWidget {
  final String licencaId;
  final AuditLicencasRepository repo;
  const ModalHistorial(
      {super.key, required this.licencaId, required this.repo});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Historial de acções'),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<List<EntradaAudit>>(
          future: repo.porLicenca(licencaId),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Text('Não foi possível ler o historial: ${snap.error}',
                  style: AppText.caption);
            }
            final entradas = snap.data ?? const <EntradaAudit>[];
            if (entradas.isEmpty) {
              return Text('Ainda não há acções remotas nesta licença.',
                  style: AppText.caption);
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: entradas.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (_, i) {
                final e = entradas[i];
                final params = e.parametrosResumidos;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      params.isEmpty ? e.acaoLabel : '${e.acaoLabel} ($params)',
                      style: AppText.body,
                    ),
                    Text(
                      '${Dates.data(e.criadoEm)} · ${e.actorRole ?? 'desconhecido'}',
                      style: AppText.caption,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
