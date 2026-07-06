import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/app_colors.dart';
import 'core/app_theme.dart';
import 'core/erros.dart';
import 'core/supabase_config.dart';
import 'features/auth/login_screen.dart';
import 'features/nav/home_shell.dart';

/// Estado de autenticação reactivo.
///
/// Semeia o estado inicial com a sessão já restaurada por
/// `Supabase.initialize()` (aguardado no `main`) e, a partir daí, reage a
/// todas as mudanças: login, logout, refresh e expiração de token.
///
/// A semente é necessária porque `onAuthStateChange` é um broadcast stream sem
/// replay: o evento `initialSession` é disparado durante `Supabase.initialize()`,
/// antes deste provider subscrever, pelo que um subscritor tardio nunca o
/// receberia e ficaria preso no splash.
final sessaoProvider = StreamProvider<Session?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentSession;
  await for (final estado in auth.onAuthStateChange) {
    yield estado.session;
  }
});

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

class WashInvoiceControlApp extends ConsumerWidget {
  const WashInvoiceControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider);
    return MaterialApp(
      title: 'WashInvoice Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: messengerKey,
      home: sessao.when(
        // Estado inicial ainda a resolver: splash neutro, sem saltar para o
        // Login (pode ainda haver sessão a restaurar do disco).
        loading: () => const _SplashScreen(),
        // Falha a ler o estado de autenticação: cai no Login por segurança.
        error: (_, __) => const LoginScreen(),
        // Sessão presente → HomeShell. Ausente (confirmado) → LoginScreen.
        data: (session) =>
            session != null ? const HomeShell() : const LoginScreen(),
      ),
    );
  }
}

/// Ecrã neutro mostrado enquanto o estado de autenticação inicial não chega.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.azul,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
