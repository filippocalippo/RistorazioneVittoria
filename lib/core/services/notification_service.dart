import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  /// Inizializza il servizio notifiche
  Future<void> initialize({
    required Function(RemoteMessage) onForegroundMessage,
    required Function(RemoteMessage) onMessageTap,
    Future<void> Function(String token)? onTokenReady,
  }) async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('[Notifications] Permissions not granted yet');
    }
    
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint('[Notifications] FCM token obtained');
      if (onTokenReady != null) {
        await onTokenReady(token);
      }
    }
    
    // Setup message handlers
    FirebaseMessaging.onMessage.listen(onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(onMessageTap);
    
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      onMessageTap(initialMessage);
    }
    
    if (onTokenReady != null) {
      _messaging.onTokenRefresh.listen((newToken) async {
        await onTokenReady(newToken);
      });
    }
    
    debugPrint('[Notifications] Service initialized');
  }
  
  /// Ottieni il token FCM corrente
  Future<String?> getToken() async {
    return _messaging.getToken();
  }
  
  /// Listener per cambio token
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}
