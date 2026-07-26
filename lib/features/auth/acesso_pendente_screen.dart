import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';

class AcessoPendenteScreen extends StatelessWidget {
  final String estado;
  const AcessoPendenteScreen({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final recusado = estado == 'recusado' || estado == 'revogado';
    return Scaffold(
      backgroundColor: AppColors.azul900,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(recusado ? Icons.block_outlined : Icons.hourglass_top,
                    size: 44, color: recusado ? AppColors.vermelho : AppColors.azul),
                const SizedBox(height: 16),
                Text(recusado ? 'Acesso indisponível' : 'Pedido em análise',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Text(recusado
                    ? 'Este acesso foi recusado ou revogado. Contacte a WashInvoice para mais informações.'
                    : 'A sua conta foi criada. O acesso será libertado depois de confirmação manual.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  icon: const Icon(Icons.logout), label: const Text('Terminar sessão'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
