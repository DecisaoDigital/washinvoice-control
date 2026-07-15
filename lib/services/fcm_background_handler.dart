import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Handler de push em segundo plano.
///
/// Tem de ser função **top-level** (fora de qualquer classe) e anotada com
/// `@pragma('vm:entry-point')` — o Flutter isola-a numa nova Dart VM quando o
/// sistema entrega o push com a app fechada/em background.
///
/// Não podemos assumir que qualquer estado da app está inicializado. Se
/// precisares de escrever no Supabase daqui, tens de re-inicializar Supabase
/// dentro desta função (por agora só logamos — o comportamento visível é a
/// notificação criada automaticamente pelo sistema a partir do `notification`
/// payload que a Edge Function envia).
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  try {
    // O Firebase pode ainda não estar inicializado neste isolate.
    await Firebase.initializeApp();
    developer.log(
      'FCM background: ${message.notification?.title} — ${message.data}',
      name: 'fcm.bg',
    );
  } catch (e, st) {
    developer.log(
      'FCM background: falha',
      error: e,
      stackTrace: st,
      name: 'fcm.bg',
    );
  }
}
