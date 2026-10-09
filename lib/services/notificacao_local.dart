import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificação do sistema para pushes que chegam com a app aberta (o FCM só
/// desenha a notificação sozinho quando a app está em background).
class NotificacaoLocal {
  NotificacaoLocal._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _pronto = false;
  static int _id = 0;

  static Future<void> _iniciar() async {
    if (_pronto) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _pronto = true;
  }

  static Future<void> mostrar(String titulo, String corpo) async {
    try {
      await _iniciar();
      await _plugin.show(
        id: _id++ & 0x7fffffff,
        title: titulo,
        body: corpo.isEmpty ? null : corpo,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'push_foreground',
            'Avisos com a app aberta',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e, st) {
      developer.log('Notificação local falhou',
          error: e, stackTrace: st, name: 'fcm');
    }
  }
}
