import 'dart:async';

import 'package:app_links/app_links.dart';
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
import 'features/auth/acesso_pendente_screen.dart';
import 'features/auth/links_de_autenticacao.dart';
import 'features/auth/modo_de_recuperacao.dart';
import 'features/auth/nova_palavra_passe_screen.dart';
import 'features/nav/home_shell.dart';
import 'repositories/providers.dart';
import 'services/fcm_background_handler.dart';
import 'services/fcm_service.dart';
import 'services/push_routing.dart';
import 'services/push_titulo.dart';

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
/// **Um erro neste canal não é uma sessão fechada.** O `getSessionFromUrl` a
/// falhar — um link de email caducado, por exemplo — é publicado como erro em
/// `onAuthStateChange`. Sem o [_semRebentar], o `await for` lançava, o gerador
/// morria com ele, e o provider ficava em erro *para sempre*: o ecrã caía no
/// Login e nunca mais recebia um evento de sessão, mesmo com a sessão viva por
/// baixo. Só um reinício da app o resolvia.
final sessaoProvider = StreamProvider<Session?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentSession;
  await for (final estado in _semRebentar(auth.onAuthStateChange)) {
    yield estado.session;
  }
});

/// A pessoa chegou por um link de recuperação e ainda não escolheu palavra-passe
/// nenhuma. Ver [modoDeRecuperacao] — é um trinco, e é ele que impede o link do
/// email de dar entrada silenciosa.
final modoRecuperacaoProvider = StreamProvider<bool>((ref) async* {
  var actual = false;
  yield actual;
  await for (final estado in _semRebentar(
    Supabase.instance.client.auth.onAuthStateChange,
  )) {
    actual = modoDeRecuperacao(estado.event, actual: actual);
    yield actual;
  }
});

/// Deixa passar os eventos e trata os erros à parte, em vez de os deixar matar
/// quem está a escutar. Diz-se ao utilizador o que aconteceu: quem carrega num
/// link de recuperação e vê a app abrir na mesma como estava conclui que
/// carregou mal, e tenta outra vez — e o link seguinte também já expirou.
Stream<AuthState> _semRebentar(Stream<AuthState> origem) =>
    origem.handleError((Object erro) {
      final mensagem = erro is AuthException
          ? 'Esse link já não serve. Pede outro em "Esqueci a palavra-passe".'
          : descreverErro(erro);
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(mensagem)),
      );
    });

/// Estado do pedido de acesso da sessão actual: `aprovado`, `pendente`,
/// `recusado` ou `revogado`.
///
/// Ter sessão Supabase não basta para entrar: o acesso é sempre libertado à
/// mão no Control. Fica num provider (e não num `FutureBuilder` inline) para
/// o RPC correr uma única vez por sessão em vez de a cada rebuild, e para
/// poder ser recarregado/substituído nos testes.
final estadoAcessoProvider = FutureProvider<String>((ref) async {
  // Depende da sessão: ao entrar ou sair, o estado é recalculado.
  ref.watch(sessaoProvider);
  return ref.read(acessosRepoProvider).meuEstado();
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
      publishableKey: SupabaseConfig.anonKey,
      // O observador de deep links de origem fica desligado: neste projecto
      // nunca entregou nada (a história está em [LinksDeAutenticacao]), e
      // deixá-lo ligado só abriria a hipótese de dois observadores a trocarem
      // o mesmo código de uso único.
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );

    final links = AppLinks();
    unawaited(
      LinksDeAutenticacao(
        links: links.uriLinkStream,
        linkInicial: links.getInitialLink,
        // A frio, esta falha acontece antes de haver ecrã — por isso a
        // mensagem espera pela interface, ver [mostrarMensagem].
        aoFalhar: (erro) => mostrarMensagem(
          erro is AuthException
              ? 'Esse link já não serve. Pede outro em '
                    '"Esqueci a palavra-passe".'
              : descreverErro(erro),
          grave: true,
        ),
      ).escutar(),
    );

    // Firebase + FCM. Não bloqueia — em falha (ex: google-services.json em
    // falta ou inválido) a app continua a funcionar sem push.
    await FcmService.inicializar(backgroundHandler: fcmBackgroundHandler);

    runApp(const ProviderScope(child: ControlApp()));
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

/// Verifica se há build novo do Control: ao ganhar sessão, ao regressar do
/// segundo plano, e como safety net diário (24h). Alinhado com o POS (#103,
/// #119) — 6h era excessivo para o cadence real de releases do Control.
/// "Side-effect only", tal como o [_fcmSincSessaoProvider]: observa
/// `sessaoProvider` e preenche `actualizacaoDisponivelProvider`, que o banner
/// e o modal em [HomeShell] mostram.
///
/// Reage à troca de *utilizador*, não a cada refresh de token (senão o timer
/// reiniciava de hora a hora). Falha de rede é engolida em silêncio — uma
/// verificação falhada nunca deve interromper o admin.
///
/// **O regresso do background conta como momento de verificar.** Sem isto há
/// só dois momentos: o arranque de raiz e o temporizador de 24 horas. Quem
/// deixa a app em segundo plano e alterna para ela nunca apanha uma versão
/// publicada entretanto — foi exactamente esta lacuna que, no Fist, deixou
/// duas versões seguidas por avisar a quem já tinha a app aberta.
final _verificadorActualizacaoProvider = Provider<void>((ref) {
  Timer? timer;
  String? ultimoUser;
  _ObservadorDeRegresso? observador;

  ref.onDispose(() {
    timer?.cancel();
    final obs = observador;
    if (obs != null) WidgetsBinding.instance.removeObserver(obs);
  });

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

  final obs = _ObservadorDeRegresso(() {
    if (ultimoUser != null) unawaited(verificar());
  });
  observador = obs;
  WidgetsBinding.instance.addObserver(obs);

  ref.listen<AsyncValue<Session?>>(sessaoProvider, (anterior, actual) {
    final userId = actual.value?.user.id;
    if (userId == ultimoUser) return; // mero refresh de token: ignorar
    ultimoUser = userId;
    timer?.cancel();
    timer = null;
    if (userId != null) {
      unawaited(verificar());
      timer = Timer.periodic(const Duration(hours: 24), (_) => verificar());
    } else {
      // Logout: limpa qualquer banner pendente para não sobreviver à sessão.
      ref.read(actualizacaoDisponivelProvider.notifier).state = null;
    }
  }, fireImmediately: true);
});

/// Observador mínimo do ciclo de vida. Existe como classe própria porque um
/// `Provider` não pode ele próprio ser um `WidgetsBindingObserver` sem
/// arrastar o mixin e o `dispose` para dentro do provider.
class _ObservadorDeRegresso extends WidgetsBindingObserver {
  _ObservadorDeRegresso(this.aoRegressar);
  final VoidCallback aoRegressar;

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) aoRegressar();
  }
}

class ControlApp extends ConsumerWidget {
  const ControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observa sessão ↔ token FCM (efeitos colaterais, sem valor devolvido).
    ref.watch(_fcmSincSessaoProvider);
    // Observa sessão → verificação de actualizações (arranque + safety net 24h).
    ref.watch(_verificadorActualizacaoProvider);

    final sessao = ref.watch(sessaoProvider);
    // **Aqui em cima, e não lá dentro do `data:`.** O `passwordRecovery` passa
    // uma vez só e não fica guardado: quem não estiver a escutar quando ele
    // passa nunca sabe que houve recuperação. Dentro do `data:` este provider
    // só era subscrito depois de a sessão resolver — e o primeiro fotograma da
    // app é sempre `loading`. Aqui subscreve ao mesmo tempo que a sessão.
    final aRecuperar = ref.watch(modoRecuperacaoProvider).value ?? false;
    return MaterialApp(
      title: 'Control',
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
        // Antes do acesso: quem entrou por um link de recuperação ainda não
        // escolheu palavra-passe nenhuma, e o link só autenticou.
        data: (session) => session == null
            ? const LoginScreen()
            : aRecuperar
            ? NovaPalavraPasseScreen(
                // Desistir tem de fechar a sessão que o link abriu. Deixá-la
                // aberta era dar entrada a quem só clicou num email.
                aoDesistir: () => Supabase.instance.client.auth.signOut(),
              )
            : const _AcessoInicial(),
      ),
    );
  }
}

class _AcessoInicial extends ConsumerWidget {
  const _AcessoInicial();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(estadoAcessoProvider).when(
      loading: () => const _SplashScreen(),
      // Sem resposta do RPC (rede em baixo, SQL de acessos ainda não aplicado)
      // não se abre a app: mostra-se o erro com retentativa, em vez de ficar
      // preso no splash.
      error: (erro, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Control'),
          actions: [
            // Escape para não ficar preso num erro persistente.
            IconButton(
              tooltip: 'Terminar sessão',
              icon: const Icon(Icons.logout),
              onPressed: () => Supabase.instance.client.auth.signOut(),
            ),
          ],
        ),
        body: ErroView(
          erro: erro,
          onRetry: () => ref.invalidate(estadoAcessoProvider),
        ),
      ),
      data: (estado) => estado == 'aprovado'
          ? const _FcmForegroundListener(child: HomeShell())
          : AcessoPendenteScreen(estado: estado),
    );
  }
}

/// Wrapper que trata os pushes enquanto há sessão activa: mostra SnackBar para
/// os que chegam com a app em foreground, e encaminha para o ecrã certo os que
/// o Cesar toca. Só é montado quando o acesso está aprovado (envolve o
/// HomeShell).
class _FcmForegroundListener extends ConsumerStatefulWidget {
  final Widget child;
  const _FcmForegroundListener({required this.child});

  @override
  ConsumerState<_FcmForegroundListener> createState() =>
      _FcmForegroundListenerState();
}

class _FcmForegroundListenerState
    extends ConsumerState<_FcmForegroundListener> {
  StreamSubscription<RemoteMessage>? _sub;
  StreamSubscription<RemoteMessage>? _subAberturas;

  @override
  void initState() {
    super.initState();

    // Toque numa notificação com a app em background. O destino sai de
    // `data['tipo']` — ver `destinoDoPush`. Quem navega é o HomeShell.
    _subAberturas = FirebaseMessaging.onMessageOpenedApp.listen((mensagem) {
      _encaminhar(mensagem);
    });

    // Toque numa notificação com a app fechada: a mensagem que a arrancou fica
    // guardada e só se lê uma vez.
    unawaited(
      FirebaseMessaging.instance.getInitialMessage().then((mensagem) {
        if (mensagem != null) _encaminhar(mensagem);
      }).catchError((_) {
        // Sem Firebase válido não há mensagem inicial — a app abre no
        // Dashboard, como sempre.
      }),
    );

    _sub = FirebaseMessaging.onMessage.listen((mensagem) {
      // `data['app']` distingue de que app veio o push (POS / Fist). Só o
      // SnackBar de foreground é prefixado — a notificação nativa é desenhada
      // pelo SO e tem de trazer o prefixo já da Edge Function.
      final titulo = tituloComApp(
        mensagem.notification?.title ?? 'Notificação',
        mensagem.data['app'] as String?,
      );
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

  /// Publica o destino do push para o HomeShell o executar. Pushes sem `tipo`
  /// (os antigos) não têm destino conhecido e ficam sem navegação — a app abre
  /// onde estava, tal como antes de haver routing.
  void _encaminhar(RemoteMessage mensagem) {
    if (!mounted) return;
    final destino = destinoDoPush(mensagem.data);
    if (destino == null) return;
    ref.read(destinoPushProvider.notifier).state = destino;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subAberturas?.cancel();
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
