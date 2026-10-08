import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../apps_ui.dart';

/// Que app o Control está a mostrar. [todas] = sem filtro — o Cesar vê o parque
/// inteiro da Decisão Digital de uma vez.
enum AppFiltro { todas, pos, punho }

extension AppFiltroExt on AppFiltro {
  String get etiqueta => switch (this) {
        AppFiltro.todas => 'Todas as apps',
        AppFiltro.pos => AppsUi.nome(AppsUi.pos),
        AppFiltro.punho => AppsUi.nome(AppsUi.punho),
      };

  /// Versão curta, para o estado fechado do selector na AppBar — onde já há
  /// wordmark e quatro ícones, e "Todas as apps" não cabe num telemóvel
  /// estreito.
  String get etiquetaCurta => switch (this) {
        AppFiltro.todas => 'Todas',
        AppFiltro.pos => 'POS',
        AppFiltro.punho => 'Fist',
      };

  /// Valor a passar a `.eq('app', …)`, ou `null` quando não se filtra.
  String? get valorApp => switch (this) {
        AppFiltro.todas => null,
        AppFiltro.pos => AppsUi.pos,
        AppFiltro.punho => AppsUi.punho,
      };

  /// A app [app] (valor bruto da coluna) passa este filtro?
  bool aceita(String app) => valorApp == null || valorApp == app;
}

/// Filtro global de app, **só em memória**.
///
/// Arranca sempre em [AppFiltro.todas]: o filtro deixou de sobreviver ao
/// arranque. Ficava guardado de uma sessão para a seguinte e a app abria a
/// mostrar só uma das apps — um caso real (licença do Fist expirada) passou
/// despercebido por isso. Enquanto a app está aberta a escolha mantém-se;
/// fechar e abrir volta a «Todas».
class AppFilterNotifier extends StateNotifier<AppFiltro> {
  AppFilterNotifier([super.inicial = AppFiltro.todas]);

  /// Mantém-se assíncrono por compatibilidade com quem já fazia `await`.
  Future<void> definir(AppFiltro filtro) async {
    if (mounted) state = filtro;
  }
}

final appFilterProvider =
    StateNotifierProvider<AppFilterNotifier, AppFiltro>((ref) => AppFilterNotifier());
