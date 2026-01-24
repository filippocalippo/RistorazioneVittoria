import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/env_config.dart';
import 'core/config/supabase_config.dart';
import 'core/config/firebase_config.dart';
import 'core/utils/logger.dart';
import 'core/models/user_model.dart';
import 'routes/app_router.dart';
import 'DesignSystem/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'providers/auth_provider.dart';
import 'providers/app_startup_provider.dart';
import 'providers/screen_persistence_provider.dart';
import 'features/auth/widgets/welcome_popup.dart';
import 'core/utils/welcome_popup_manager.dart';
import 'core/widgets/app_splash_overlay.dart';
import 'package:auto_updater/auto_updater.dart';
import 'core/services/stripe_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system UI overlay - transparent status bar allows modal overlays to work properly
  // especially on Huawei devices where solid colors prevent modal barrier dimming
  // Enable edge-to-edge mode BEFORE setting overlay style
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      // Critical flag to prevent Huawei from forcing status bar contrast
      systemStatusBarContrastEnforced: false,
    ),
  );

  try {
    // 1. Carica variabili ambiente
    Logger.info('Loading environment...', tag: 'Main');
    await EnvConfig.load();
    EnvConfig.printStatus();

    if (!EnvConfig.isValid) {
      throw Exception(
        'Invalid environment configuration. Check your .env file.',
      );
    }

    // 2. Inizializza Supabase
    Logger.info('Initializing Supabase...', tag: 'Main');
    await SupabaseConfig.initialize();

    // 3. Test connessione Supabase
    final connected = await SupabaseConfig.testConnection();
    if (!connected) {
      Logger.warning('Warning: Could not connect to Supabase', tag: 'Main');
    }

    // 4. Inizializza Firebase
    Logger.info('Initializing Firebase...', tag: 'Main');
    await FirebaseConfig.initialize();

    // 5.1 Inizializza i dati di localizzazione per Intl (es. it_IT)
    Logger.info('Initializing locales (Intl)...', tag: 'Main');
    await initializeDateFormatting('it_IT');
    Intl.defaultLocale = 'it_IT';

    // 6. Initialize Stripe SDK (for card payments)
    Logger.info('Initializing Stripe...', tag: 'Main');
    await StripeService.initialize();

    // 7. Initialize Auto Updater (Windows only)
    // 5.2 Initialize Auto Updater (Windows only)
    if (EnvConfig.isWindows) {
      Logger.info('Initializing Auto Updater...', tag: 'Main');
      try {
        final supabaseUri = Uri.tryParse(EnvConfig.supabaseUrl);
        final host = supabaseUri?.host;
        final projectId = host?.split('.').first;
        if (projectId == null || projectId.isEmpty) {
          throw Exception('Supabase project ID not found in SUPABASE_URL');
        }
        final feedUrl =
            'https://$projectId.supabase.co/storage/v1/object/public/updates/appcast.xml';

        await autoUpdater.setFeedURL(feedUrl);
        await autoUpdater.setScheduledCheckInterval(3600); // Check every hour

        // Check for updates immediately on startup
        // This will automatically show the native update dialog if an update is found
        await autoUpdater.checkForUpdates();
      } catch (e) {
        Logger.error('Failed to initialize auto updater: $e', tag: 'Main');
      }
    }

    Logger.info('Initialization complete!', tag: 'Main');
    Logger.info('========================', tag: 'Main');

    // 5. Avvia app
    runApp(const ProviderScope(child: RotanteApp()));
  } catch (e, stackTrace) {
    Logger.error(
      'Initialization failed: $e',
      tag: 'Main',
      error: e,
      stackTrace: stackTrace,
    );

    // Mostra errore all'utente
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Errore di Inizializzazione',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Verifica:\n'
                    '1. File .env esiste e contiene le credenziali\n'
                    '2. Supabase è configurato correttamente\n'
                    '3. La pizzeria esiste nel database',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// pizzeriaIdProvider removed - no longer needed for single-tenant

class RotanteApp extends ConsumerStatefulWidget {
  const RotanteApp({super.key});

  @override
  ConsumerState<RotanteApp> createState() => _RotanteAppState();
}

class _RotanteAppState extends ConsumerState<RotanteApp>
    with WidgetsBindingObserver {
  String? _lastUserId;
  String? _currentRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save current route when app goes to background
    if (state == AppLifecycleState.paused && _currentRoute != null) {
      ref
          .read(screenPersistenceProvider.notifier)
          .saveCurrentScreen(_currentRoute!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final startupState = ref.watch(appStartupProvider);

    // Track current route
    router.routerDelegate.addListener(() {
      final location = router.routerDelegate.currentConfiguration.uri.path;
      if (_currentRoute != location) {
        _currentRoute = location;
      }
    });

    // Listen to auth state changes to show welcome popup
    ref.listen<AsyncValue<UserModel?>>(authProvider, (previous, next) {
      // Only show if mounted
      if (!mounted) return;

      // Get current user
      final user = next.value;

      // Check if this is a fresh login (not app restart)
      final bool isFreshLogin = previous?.value == null && user != null;
      final bool isDifferentUser =
          previous?.value?.id != user?.id && user != null;

      // Show welcome popup only when:
      // 1. User just logged in (previous was null or different user)
      // 2. User has nome and cognome
      // 3. We haven't shown it yet for this user (persisted in storage)
      if (user != null &&
          user.nome != null &&
          user.cognome != null &&
          (isFreshLogin || isDifferentUser) &&
          _lastUserId != user.id) {
        // Mark as shown for this user in session
        _lastUserId = user.id;

        // Check persistent storage before showing
        WelcomePopupManager.hasBeenShown().then((hasShown) {
          if (hasShown) return; // Already shown, skip

          // Show popup after navigation completes
          Future.delayed(const Duration(milliseconds: 800), () async {
            if (!mounted) return;

            // Get navigator context
            final navigatorContext =
                router.routerDelegate.navigatorKey.currentContext;

            if (navigatorContext == null) return;

            // Mark as shown in storage before displaying
            await WelcomePopupManager.markAsShown();

            if (mounted && navigatorContext.mounted) {
              WelcomePopup.show(navigatorContext, user.nome!, user.cognome!);
            }
          });
        });
      }

      // Reset flag when user logs out
      if (user == null && previous?.value != null) {
        _lastUserId = null;
      }
    });

    return AppSplashOverlay(
      isLoading: startupState.isLoading,
      child: MaterialApp.router(
        title: 'Rotante',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    );
  }
}
