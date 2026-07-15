import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_colors.dart';

/// Chave global do ScaffoldMessenger — permite mostrar erros a partir de
/// qualquer sítio, mesmo sem um [BuildContext] à mão (ex.: erros assíncronos
/// não capturados).
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Converte qualquer erro numa mensagem legível em português.
String descreverErro(Object erro) {
  if (erro is AuthException) {
    final msg = erro.message.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('credentials')) {
      return 'Email ou password incorrectos.';
    }
    return erro.message;
  }
  if (erro is PostgrestException) {
    switch (erro.code) {
      case '42501': // insufficient_privilege
        return 'Sem permissão para esta operação. Verifica as políticas '
            'de acesso (RLS) no Supabase.';
      case 'PGRST301': // JWT expired
        return 'A sessão expirou. Volta a iniciar sessão.';
      case '23505': // unique_violation
        if (erro.message.contains('licencas_serie_activa_unique') ||
            (erro.details?.toString().toLowerCase().contains('serie') ??
                false)) {
          return 'Já existe uma licença activa com essa série. Cada terminal '
              'activo tem de ter uma série única.';
        }
        return 'Já existe um registo com esses dados (valor duplicado).';
    }
    return 'Erro do servidor: ${erro.message}';
  }
  if (erro is SocketException ||
      erro is HttpException ||
      erro.toString().contains('SocketException')) {
    return 'Sem ligação à internet ou servidor inacessível.';
  }
  return 'Ocorreu um erro: $erro';
}

/// Mostra um erro num SnackBar vermelho. Pode ser chamado de qualquer ponto.
void mostrarErro(Object erro, {StackTrace? stack}) {
  // Deixa também rasto na consola para diagnóstico.
  debugPrint('ERRO: $erro');
  if (stack != null) debugPrint(stack.toString());

  final messenger = messengerKey.currentState;
  messenger
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        backgroundColor: AppColors.vermelho,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Text(descreverErro(erro)),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
}

/// Instala os handlers globais para que nenhum erro fique silencioso.
/// Chamar dentro de [runZonedGuarded] em main().
void instalarHandlersDeErro() {
  // Erros do framework Flutter (build/layout/etc.) — registados na consola.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  // Erros assíncronos não capturados — surgem ao utilizador.
  PlatformDispatcher.instance.onError = (erro, stack) {
    mostrarErro(erro, stack: stack);
    return true;
  };
}

/// Vista reutilizável de erro com botão de tentar de novo, para usar em
/// FutureBuilders.
class ErroView extends StatelessWidget {
  final Object erro;
  final VoidCallback onRetry;

  const ErroView({super.key, required this.erro, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.vermelho, size: 48),
            const SizedBox(height: 12),
            Text(
              descreverErro(erro),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
