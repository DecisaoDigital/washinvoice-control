import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/erros.dart';
import '../../../repositories/providers.dart';
import '../../../repositories/punho_admin_repository.dart';
import 'punho_editar_limite_modal.dart';

/// Empresas do Punho e o limite de colaboradores activos de cada uma —
/// alcançado a partir de "Pedidos Punho" (botão na AppBar), não é um
/// separador próprio: é a mesma administração de Punho, só noutra vista.
///
/// A criação de empresa continua a acontecer só ao aprovar um pedido livre
/// (`PunhoDecidirModal`); este ecrã serve só para reajustar o limite depois,
/// sem passar por um pedido novo.
class PunhoEmpresasScreen extends ConsumerStatefulWidget {
  const PunhoEmpresasScreen({super.key});

  @override
  ConsumerState<PunhoEmpresasScreen> createState() =>
      _PunhoEmpresasScreenState();
}

class _PunhoEmpresasScreenState extends ConsumerState<PunhoEmpresasScreen> {
  late Future<List<PunhoEmpresa>> _future;
  bool _aGravar = false;

  @override
  void initState() {
    super.initState();
    _recarregar();
  }

  void _recarregar() {
    _future = ref.read(punhoAdminRepoProvider).listarEmpresas();
  }

  Future<void> _editarLimite(PunhoEmpresa empresa) async {
    final escolha = await showDialog<NovoLimite>(
      context: context,
      builder: (_) => PunhoEditarLimiteModal(empresa: empresa),
    );
    if (escolha == null) return;

    setState(() => _aGravar = true);
    try {
      await ref
          .read(punhoAdminRepoProvider)
          .definirLimite(empresa.id, escolha.valor);
      if (!mounted) return;
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Limite de ${empresa.nome} passou a ${escolha.valor}.'),
        ),
      );
      setState(_recarregar);
    } catch (e) {
      if (mounted) mostrarErro(e);
    } finally {
      if (mounted) setState(() => _aGravar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Empresas Punho'),
        actions: [
          IconButton(
            tooltip: 'Recarregar',
            icon: const Icon(Icons.refresh),
            onPressed: _aGravar ? null : () => setState(_recarregar),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_aGravar) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: FutureBuilder<List<PunhoEmpresa>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return ErroView(
                    erro: snap.error!,
                    onRetry: () => setState(_recarregar),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final empresas = snap.data!;
                if (empresas.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Text('Ainda não há empresas Punho.'),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_recarregar);
                    await _future;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: empresas.length,
                    itemBuilder: (_, i) => _EmpresaCard(
                      empresa: empresas[i],
                      ocupado: _aGravar,
                      onEditar: () => _editarLimite(empresas[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmpresaCard extends StatelessWidget {
  const _EmpresaCard({
    required this.empresa,
    required this.ocupado,
    required this.onEditar,
  });

  final PunhoEmpresa empresa;
  final bool ocupado;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final e = empresa;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.nome,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${e.ocupacao} colaboradores activos',
                    style: TextStyle(
                      color: e.noLimite
                          ? AppColors.laranja700
                          : AppColors.textSecondary,
                      fontWeight: e.noLimite
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (e.noLimite)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        'No limite — novos colaboradores ficam sem acesso até '
                        'autorizares.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.laranja700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: ocupado ? null : onEditar,
              child: const Text('Editar limite'),
            ),
          ],
        ),
      ),
    );
  }
}
