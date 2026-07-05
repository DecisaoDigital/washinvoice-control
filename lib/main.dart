import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/app_theme.dart';
import 'core/erros.dart';
import 'core/supabase_config.dart';
import 'features/auth/login_screen.dart';
import 'features/nav/home_shell.dart';

Future<void> main() async {
  // Toda a app corre dentro de uma zona protegida: qualquer erro assíncrono
  // não capturado é encaminhado para o tratamento central de erros.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      instalarHandlersDeErro();

      timeago.setLocaleMessages('pt', timeago.PtBrMessages());

      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );

      runApp(const ProviderScope(child: WashInvoiceControlApp()));
    },
    (erro, stack) => mostrarErro(erro, stack: stack),
  );
}

class WashInvoiceControlApp extends StatelessWidget {
  const WashInvoiceControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final temSessao = Supabase.instance.client.auth.currentSession != null;
    return MaterialApp(
      title: 'WashInvoice Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: messengerKey,
      home: temSessao ? const HomeShell() : const LoginScreen(),
    );
  }
}
