import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço de FCM — inicializa Firebase, pede permissão, obtém o token e
/// mantém-no sincronizado com a tabela `admin_dispositivos` no Supabase.
///
/// Fluxo:
///   1. `inicializar()` — no arranque, antes do runApp. Só inicializa Firebase
///      e regista o background handler; não pede permissão nem token.
///   2. `registarParaSessao(userId)` — chamado depois do login. Pede permissão,
///      obtém o token e faz upsert em `admin_dispositivos`.
///   3. `desregistarSessaoAtual()` — chamado no logout. Remove o token deste
///      dispositivo da tabela (o dispositivo continua a receber pushes até o
///      Cesar voltar a autenticar; simplesmente não fica associado ao user).
class FcmService {
  FcmService._();

  static const _tabela = 'admin_dispositivos';

  /// Guarda o token que registámos por último para permitir apagá-lo no logout
  /// (o token do dispositivo pode mudar durante a sessão).
  static String? _tokenRegistado;
  static String? _userIdRegistado;
  static StreamSubscription<String>? _refreshSub;

  /// Token FCM actualmente registado (para exibição no ecrã Sobre/Sistema).
  /// `null` = ainda não registado ou logout.
  static String? get tokenRegistado => _tokenRegistado;

  /// Inicializa Firebase e regista o background handler. Chamar antes de
  /// `runApp()`. Em falha (ex: sem `google-services.json` correcto) engole o
  /// erro — a app continua a funcionar, só não recebe pushes.
  static Future<void> inicializar({
    required Future<void> Function(RemoteMessage) backgroundHandler,
  }) async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(backgroundHandler);
    } catch (e, st) {
      developer.log('FCM: falha a inicializar Firebase', error: e, stackTrace: st, name: 'fcm');
    }
  }

  /// Regista o token deste dispositivo em `admin_dispositivos` para [userId].
  /// Idempotente — chamar múltiplas vezes é seguro. Não bloqueia a UI: falhas
  /// (rede, permissão negada) são logadas mas não propagadas.
  static Future<void> registarParaSessao(String userId) async {
    try {
      // Pedir permissão (iOS/Android 13+).
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        developer.log('FCM: permissão negada pelo utilizador', name: 'fcm');
        return;
      }

      // Obter token.
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        developer.log('FCM: token nulo/vazio', name: 'fcm');
        return;
      }

      await _upsertToken(userId: userId, token: token);
      _tokenRegistado = token;
      _userIdRegistado = userId;

      // Reagir a rotação de token durante a sessão.
      await _refreshSub?.cancel();
      _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((novo) async {
        try {
          if (_userIdRegistado == null) return;
          await _upsertToken(userId: _userIdRegistado!, token: novo);
          _tokenRegistado = novo;
        } catch (e, st) {
          developer.log('FCM: falha no refresh de token', error: e, stackTrace: st, name: 'fcm');
        }
      });
    } catch (e, st) {
      developer.log('FCM: falha a registar para sessão', error: e, stackTrace: st, name: 'fcm');
    }
  }

  /// Remove o token deste dispositivo da tabela (chamar no logout).
  static Future<void> desregistarSessaoAtual() async {
    final token = _tokenRegistado;
    final userId = _userIdRegistado;
    _tokenRegistado = null;
    _userIdRegistado = null;
    await _refreshSub?.cancel();
    _refreshSub = null;

    if (token == null || userId == null) return;
    try {
      await Supabase.instance.client
          .from(_tabela)
          .delete()
          .eq('user_id', userId)
          .eq('fcm_token', token);
    } catch (e, st) {
      developer.log('FCM: falha a desregistar token', error: e, stackTrace: st, name: 'fcm');
    }
  }

  /// UPSERT do token na tabela. Actualiza `actualizado_em` a cada chamada.
  static Future<void> _upsertToken({
    required String userId,
    required String token,
  }) async {
    final plataforma = _plataformaActual();
    await Supabase.instance.client.from(_tabela).upsert(
      {
        'user_id': userId,
        'fcm_token': token,
        'plataforma': plataforma,
        'actualizado_em': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,fcm_token',
    );
  }

  static String _plataformaActual() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }
}
