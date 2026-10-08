import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../repositories/providers.dart';
import '../../../repositories/punho_admin_repository.dart';
import '../gestao_acessos_screen.dart' show souAdminGlobalProvider;
import 'punho_pedidos_screen.dart' show punhoPedidosRefreshProvider;

/// Pedidos de acesso ao Fist **pendentes**, para as contagens (badges) e para a
/// fila «Agora».
///
/// Só o admin global os pode ler (as RPCs `punho_*_admin` recusam o resto):
/// para qualquer outra conta devolve vazio sem sequer chamar o servidor. Quem
/// precisar de dados frescos faz `ref.invalidate(fistPendentesProvider)`; o
/// ticker [punhoPedidosRefreshProvider] (entrada no ecrã, push) também o refaz.
final fistPendentesProvider = FutureProvider<List<FistPedido>>((ref) async {
  ref.watch(punhoPedidosRefreshProvider);
  final admin = await ref.watch(souAdminGlobalProvider.future);
  if (!admin) return const [];
  return ref.read(punhoAdminRepoProvider).listarPedidos(estado: 'pendente');
});

/// Quantos pedidos Fist pendentes há (0 enquanto carrega ou se falhar — uma
/// contagem em badge nunca deve rebentar o ecrã).
final fistPendentesTotalProvider = Provider<int>(
  (ref) => ref.watch(fistPendentesProvider).valueOrNull?.length ?? 0,
);
