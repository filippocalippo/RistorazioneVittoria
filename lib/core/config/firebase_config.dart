import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../firebase_options.dart';
import '../../core/utils/logger.dart';
import 'env_config.dart';
import 'supabase_config.dart';

/// Handler per messaggi in background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final ready =
      await FirebaseConfig.ensureBackgroundInitialized(logWarnings: false);
  if (!ready) {
    Logger.debug(
      'Received background message but Firebase is not configured.',
      tag: 'Firebase',
    );
    return;
  }
  Logger.debug('Handling background message', tag: 'Firebase');
}

/// Configurazione Firebase
class FirebaseConfig {
  static bool _initializing = false;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  static String? _pendingFcmToken;

  /// Inizializza Firebase e FCM (idempotente).
  static Future<void> initialize() async {
    final ready = await _ensureInitialized();
    if (!ready) {
      Logger.warning(
        'Firebase not initialized. Push notifications will be disabled.',
        tag: 'Firebase',
      );
      return;
    }

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }

    await _initializeLocalNotifications();
    await _configureMessaging();
    _setupAuthStateListener();
  }

  /// Garantisce l'inizializzazione anche nei background isolate.
  static Future<bool> ensureBackgroundInitialized({
    bool logWarnings = true,
  }) =>
      _ensureInitialized(logWarnings: logWarnings);

  static Future<bool> _ensureInitialized({bool logWarnings = true}) async {
    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    if (_initializing) {
      // Wait for in-flight initialization.
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return Firebase.apps.isNotEmpty;
    }

    _initializing = true;
    try {
      if (!EnvConfig.isLoaded) {
        await EnvConfig.load();
      }

      final options = DefaultFirebaseOptions.currentPlatform;

      await Firebase.initializeApp(options: options);
      Logger.info('✓ Firebase initialized', tag: 'Firebase');
      return true;
    } catch (e, stack) {
      if (logWarnings) {
        Logger.error(
          '❌ Firebase initialization failed: $e',
          tag: 'Firebase',
          error: e,
          stackTrace: stack,
        );
      }
      return false;
    } finally {
      _initializing = false;
    }
  }

  static Future<void> _configureMessaging() async {
    if (kIsWeb) {
      Logger.info(
        'Firebase Messaging web support must be configured manually (service worker, vapid key).',
        tag: 'Firebase',
      );
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          Logger.info('✓ FCM permissions granted', tag: 'Firebase');
          break;
        case AuthorizationStatus.provisional:
          Logger.warning(
            '⚠️ FCM provisional permissions granted',
            tag: 'Firebase',
          );
          break;
        case AuthorizationStatus.denied:
        case AuthorizationStatus.notDetermined:
          Logger.warning(
            '⚠️ FCM permissions not granted. Notifications will be disabled.',
            tag: 'Firebase',
          );
          return;
      }

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        Logger.debug(
          'FCM token retrieved (value hidden for privacy).',
          tag: 'Firebase',
        );
        
        // Save token to database
        await _saveFcmToken(token);
      }

      messaging.onTokenRefresh.listen((newToken) async {
        Logger.debug('FCM token refreshed', tag: 'Firebase');
        await _saveFcmToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      Logger.info(
        '✓ Firebase Messaging configured',
        tag: 'Firebase',
      );
    } catch (e, stack) {
      Logger.error(
        '❌ Error configuring Firebase Messaging: $e',
        tag: 'Firebase',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Initialize local notifications for foreground messages
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);
    Logger.info('✓ Local notifications initialized', tag: 'Firebase');
  }

  /// Handle messages when app is in foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    Logger.info('🔔 Foreground message received: ${message.notification?.title}', tag: 'Firebase');
    
    // Show local notification
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'Default notification channel',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Rotante',
      message.notification?.body ?? 'Nuova notifica',
      details,
      payload: message.data.toString(),
    );
  }

  /// Sets up auth state listener to save FCM token when user logs in
  static void _setupAuthStateListener() {
    SupabaseConfig.client.auth.onAuthStateChange.listen((event) {
      if (event.event == supabase.AuthChangeEvent.signedIn && _pendingFcmToken != null) {
        Logger.info('🔐 User signed in, saving pending FCM token', tag: 'Firebase');
        _saveFcmToken(_pendingFcmToken!);
      }
    });
  }

  /// Public method to manually save/update FCM token (e.g., after login)
  static Future<void> saveFcmTokenForCurrentUser() async {
    try {
      if (kIsWeb) {
        Logger.debug('FCM token save skipped on web', tag: 'Firebase');
        return;
      }

      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      
      if (token != null && token.isNotEmpty) {
        await _saveFcmToken(token);
      }
    } catch (e) {
      Logger.warning('⚠️ Failed to save FCM token for current user: $e', tag: 'Firebase');
    }
  }

  /// Salva il token FCM nel database dell'utente corrente
  static Future<void> _saveFcmToken(String token) async {
    try {
      final currentUser = SupabaseConfig.client.auth.currentUser;
      if (currentUser == null) {
        Logger.debug('No user logged in, storing token as pending', tag: 'Firebase');
        _pendingFcmToken = token;
        return;
      }

      await SupabaseConfig.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', currentUser.id);

      Logger.info('✓ FCM token saved to database', tag: 'Firebase');
      _pendingFcmToken = null; // Clear pending token after successful save
    } catch (e) {
      Logger.warning(
        '⚠️ Failed to save FCM token: $e',
        tag: 'Firebase',
      );
      // Non fare rethrow per evitare crash dell'app
    }
  }
}
