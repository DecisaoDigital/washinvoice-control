import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../apps_ui.dart';

/// Que app o Control está a mostrar. [todas] = sem filtro — o Cesar vê o parque
/// inteiro da Decisão Digital de uma vez.
enum AppFiltro { todas, pos, punho }

const kPrefFiltroApp = 'app_filtro';

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

/// Filtro global de app, persistido em SharedPreferences.
///
/// Arranca sempre em [AppFiltro.todas] e só depois lê a preferência guardada —
/// a leitura é assíncrona. Os ecrãs reagem à mudança via `ref.listen`, por isso
/// o estado inicial "errado" durante alguns milissegundos apenas provoca um
/// recarregamento extra, não uma vista errada persistente.
class AppFilterNotifier extends StateNotifier<AppFiltro> {
  AppFilterNotifier() : super(AppFiltro.todas) {
    carregado = _carregar();
  }

  /// Completa quando a preferência guardada já foi aplicada ao estado. Existe
  /// para os testes poderem esperar sem `pumpAndSettle` arbitrário.
  late final Future<void> carregado;

  Future<void> _carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(kPrefFiltroApp);
    if (!mounted) return;
    state = AppFiltro.values.firstWhere(
      (f) => f.name == guardado,
      orElse: () => AppFiltro.todas,
    );
  }

  Future<void> definir(AppFiltro filtro) async {
    if (mounted) state = filtro;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefFiltroApp, filtro.name);
  }
}

final appFilterProvider =
    StateNotifierProvider<AppFilterNotifier, AppFiltro>((ref) => AppFilterNotifier());
