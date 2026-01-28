import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/logger.dart';
import 'pizzeria_settings_provider.dart';
import 'auth_provider.dart';
import 'screen_persistence_provider.dart';
import 'organization_provider.dart';

part 'app_startup_provider.g.dart';

/// Provider that manages app startup and ensures critical data is loaded
/// Shows splash screen for minimum duration and until essential providers are ready
@riverpod
Future<void> appStartup(Ref ref) async {
  const minimumSplashDuration = Duration(milliseconds: 800);
  final startTime = DateTime.now();

  Logger.info('App startup initiated', tag: 'AppStartup');

  try {
    // Load critical providers in parallel
    await Future.wait([
      // Essential providers that must load before showing UI
      ref.watch(pizzeriaSettingsProvider.future),
      ref.watch(authProvider.future),
      ref.read(screenPersistenceProvider.future),
      ref.watch(currentOrganizationProvider.future),

      // Add any other critical providers here
      // ref.watch(categoriesProvider.future),
    ]);

    Logger.info('Critical providers loaded', tag: 'AppStartup');

    // Ensure minimum splash duration for smooth UX
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < minimumSplashDuration) {
      final remaining = minimumSplashDuration - elapsed;
      Logger.debug(
        'Waiting ${remaining.inMilliseconds}ms to meet minimum splash duration',
        tag: 'AppStartup',
      );
      await Future.delayed(remaining);
    }

    Logger.info(
      'App startup complete in ${DateTime.now().difference(startTime).inMilliseconds}ms',
      tag: 'AppStartup',
    );
  } catch (e, stack) {
    Logger.error(
      'Error during app startup: $e',
      tag: 'AppStartup',
      error: e,
      stackTrace: stack,
    );

    // Still enforce minimum duration even on error
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < minimumSplashDuration) {
      await Future.delayed(minimumSplashDuration - elapsed);
    }

    rethrow;
  }
}
