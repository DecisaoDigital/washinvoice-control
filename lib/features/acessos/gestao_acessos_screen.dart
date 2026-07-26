import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/erros.dart';
import '../../repositories/providers.dart';
import 'convites_screen.dart';
import 'pedidos_acesso_screen.dart';

/// O separador Acessos mostra coisas diferentes conforme o perfil: o admin
/// global gere todos os pedidos; um gerente de organização só convida pessoas
/// para a sua.
final souAdminGlobalProvider = FutureProvider<bool>(
  (ref) => ref.read(acessosRepoProvider).souAdminGlobal(),
);

class GestaoAcessosScreen extends ConsumerWidget {
  const GestaoAcessosScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(souAdminGlobalProvider).when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (erro, _) => Scaffold(
          appBar: AppBar(title: const Text('Acessos')),
          body: ErroView(
            erro: erro,
            onRetry: () => ref.invalidate(souAdminGlobalProvider),
          ),
        ),
        data: (admin) => admin ? const PedidosAcessoScreen() : const ConvitesScreen(),
      );
}
