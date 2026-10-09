import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Itens do «Agora» a que o Cesar já ligou hoje. Descem para «Tratados» mas
/// continuam abertos (falta «Resolvido»). Guarda-se por dia: à meia-noite a
/// lista esvazia-se sozinha e o item, se ainda estiver aberto, volta ao topo.
class LigadosNotifier extends StateNotifier<Set<String>> {
  LigadosNotifier() : super(const {}) {
    _carregar();
  }

  static const _chave = 'agora_ligados_v1';

  static String _hoje() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefixo = '${_hoje()}|';
      final hoje = (prefs.getStringList(_chave) ?? const <String>[])
          .where((e) => e.startsWith(prefixo))
          .map((e) => e.substring(prefixo.length))
          .toSet();
      if (mounted) state = hoje;
    } catch (_) {
      // Sem armazenamento, a lista só dura enquanto a app estiver aberta.
    }
  }

  Future<void> _guardar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_chave, [
        for (final c in state) '${_hoje()}|$c',
      ]);
    } catch (_) {}
  }

  Future<void> marcar(String chave) async {
    state = {...state, chave};
    await _guardar();
  }

  Future<void> desmarcar(String chave) async {
    state = {...state}..remove(chave);
    await _guardar();
  }
}

final ligadosProvider = StateNotifierProvider<LigadosNotifier, Set<String>>(
  (_) => LigadosNotifier(),
);
