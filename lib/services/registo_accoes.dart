import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/providers.dart';

/// Regista no Histórico o que o Cesar acabou de fazer. **Nunca bloqueia nem
/// falha a acção**: se o registo não gravar, a acção já está feita e só se perde
/// a linha do Histórico.
Future<void> registarAccao(
  WidgetRef ref, {
  required String tipo,
  required String titulo,
  required String accao,
  String? app,
  String? pedido,
  String? machineId,
}) async {
  try {
    await ref.read(historicoRepoProvider).registar(
          tipo: tipo,
          titulo: titulo,
          accao: accao,
          app: app,
          pedido: pedido,
          machineId: machineId,
        );
    ref.invalidate(historicoProvider);
  } catch (e, st) {
    developer.log('Histórico: falha a registar', error: e, stackTrace: st, name: 'historico');
  }
}
