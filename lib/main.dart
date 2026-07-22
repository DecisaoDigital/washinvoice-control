import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/app_colors.dart';
import 'core/app_theme.dart';
import 'core/erros.dart';
import 'core/supabase_config.dart';
import 'features/auth/login_screen.dart';
import 'features/nav/home_shell.dart';
import 'repositories/providers.dart';
import 'services/fcm_background_handler.dart';
import 'services/fcm_service.dart';

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

/// Sinal para o Dashboard recarregar quando chega um push relevante (novo
/// pedido de ajuda, nova instalação). O [_FcmForegroundListener] emite; o
/// [DashboardScreen] escuta em `initState` e chama `_recarregar()`.
final _dashboardRefreshCtrl = StreamController<void>.broadcast();
final dashboardRefreshProvider = Provider<Stream<void>>(
  (ref) => _dashboardRefreshCtrl.stream,
);

Future<void> main() async {
  // Toda a app corre dentro de uma zona protegida: qualquer erro assíncrono
  // não capturado é encaminhado para o tratamento central de erros.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    instalarHandlersDeErro();

    timeago.setLocaleMessages('pt', timeago.PtBrMessages());

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    // Firebase + FCM. Não bloqueia — em falha (ex: google-services.json em
    // falta ou inválido) a app continua a funcionar sem push.
    await FcmService.inicializar(backgroundHandler: fcmBackgroundHandler);

    runApp(const ProviderScope(child: WashInvoiceControlApp()));
  }, (erro, stack) => mostrarErro(erro, stack: stack));
}

/// Sincroniza o registo do token FCM com a sessão actual: regista quando entra
/// sessão nova, remove quando termina. É um provider "side-effect only" — não
/// expõe estado, só observa `sessaoProvider` e chama o [FcmService].
final _fcmSincSessaoProvider = Provider<void>((ref) {
  String? ultimoUserId;
  ref.listen<AsyncValue<Session?>>(sessaoProvider, (anterior, actual) {
    final novo = actual.value?.user.id;
    if (novo == ultimoUserId) return;
    if (novo != null) {
      unawaited(FcmService.registarParaSessao(novo));
    } else {
      unawaited(FcmService.desregistarSessaoAtual());
    }
    ultimoUserId = novo;
  }, fireImmediately: true);
});

/// Verifica se há build novo do Control: uma vez ao ganhar sessão e depois a
/// cada 6 horas. "Side-effect only", tal como o [_fcmSincSessaoProvider]:
/// observa `sessaoProvider` e preenche `actualizacaoDisponivelProvider`, que o
/// banner e o modal em [HomeShell] mostram.
///
/// Reage à troca de *utilizador*, não a cada refresh de token (senão o timer
/// reiniciava de hora a hora). Falha de rede é engolida em silêncio — uma
/// verificação falhada nunca deve interromper o admin.
final _verificadorActualizacaoProvider = Provider<void>((ref) {
  Timer? timer;
  String? ultimoUser;

  ref.onDispose(() => timer?.cancel());

  Future<void> verificar() async {
    try {
      final info = await ref.read(actualizacaoServiceProvider).verificar();
      if (info != null) {
        ref.read(actualizacaoDisponivelProvider.notifier).state = info;
      }
    } catch (_) {
      // Rede off / servidor em baixo: silencioso de propósito.
    }
  }

  ref.listen<AsyncValue<Session?>>(sessaoProvider, (anterior, actual) {
    final userId = actual.value?.user.id;
    if (userId == ultimoUser) return; // mero refresh de token: ignorar
    ultimoUser = userId;
    timer?.cancel();
    timer = null;
    if (userId != null) {
      unawaited(verificar());
      timer = Timer.periodic(const Duration(hours: 6), (_) => verificar());
    } else {
      // Logout: limpa qualquer banner pendente para não sobreviver à sessão.
      ref.read(actualizacaoDisponivelProvider.notifier).state = null;
    }
  }, fireImmediately: true);
});

class WashInvoiceControlApp extends ConsumerWidget {
  const WashInvoiceControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observa sessão ↔ token FCM (efeitos colaterais, sem valor devolvido).
    ref.watch(_fcmSincSessaoProvider);
    // Observa sessão → verificação de actualizações (arranque + timer 6h).
    ref.watch(_verificadorActualizacaoProvider);

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
        data: (session) => session != null
            ? const _FcmForegroundListener(child: HomeShell())
            : const LoginScreen(),
      ),
    );
  }
}

/// Wrapper que escuta pushes recebidos com a app em foreground e mostra
/// SnackBar. Só é montado quando há sessão activa (dentro do HomeShell).
class _FcmForegroundListener extends StatefulWidget {
  final Widget child;
  const _FcmForegroundListener({required this.child});

  @override
  State<_FcmForegroundListener> createState() => _FcmForegroundListenerState();
}

class _FcmForegroundListenerState extends State<_FcmForegroundListener> {
  StreamSubscription<RemoteMessage>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseMessaging.onMessage.listen((mensagem) {
      final titulo = mensagem.notification?.title ?? 'Notificação';
      final corpo = mensagem.notification?.body ?? '';

      // O SnackBar em foreground é silencioso (ao contrário da notificação
      // nativa em background). Vibrar dá o mesmo aviso físico.
      HapticFeedback.mediumImpact();

      // Recarrega o Dashboard. Single-admin: qualquer push que chega é
      // relevante (novo terminal / pedido de ajuda), por isso recarrega sempre.
      _dashboardRefreshCtrl.add(null);

      final ctx = messengerKey.currentContext;
      if (ctx == null) return;
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(corpo.isEmpty ? titulo : '$titulo — $corpo'),
          duration: const Duration(seconds: 6),
        ),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Ecrã neutro mostrado enquanto o estado de autenticação inicial não chega.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.azul,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
