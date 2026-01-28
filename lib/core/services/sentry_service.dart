import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../utils/logger.dart';

/// Sentry Service
///
/// Centralized error tracking and performance monitoring for the Flutter app.
/// Integrates with Sentry.io for production error monitoring.
///
/// Part of Section 8.2 Backend Production Readiness
class SentryService {
  static bool _isInitialized = false;

  /// Initializes Sentry for error tracking
  ///
  /// Should be called once during app startup (in main.dart)
  ///
  /// Parameters:
  /// - [dsn]: The Sentry DSN (defaults to env var SENTRY_DSN_FLUTTER)
  /// - [environment]: The environment (production/staging/development)
  /// - [release]: The app release version
  static Future<void> initialize({
    String? dsn,
    String? environment,
    String? release,
  }) async {
    if (_isInitialized) {
      Logger.info('Sentry already initialized', tag: 'Sentry');
      return;
    }

    // Get DSN from parameter or environment
    final sentryDsn = dsn ?? const String.fromEnvironment('SENTRY_DSN_FLUTTER', defaultValue: '');

    // Use placeholder if no DSN provided
    if (sentryDsn.isEmpty || sentryDsn.contains('examplePublicKey')) {
      Logger.warning(
        'Sentry DSN not configured or is placeholder. Error tracking disabled.',
        tag: 'Sentry',
      );
      _isInitialized = false;
      return;
    }

    try {
      await SentryFlutter.init(
        (options) {
          options.dsn = sentryDsn;
          options.environment = environment ?? _getEnvironment();
          options.release = release ?? _getRelease();
          options.tracesSampleRate = 0.1; // 10% of transactions
          options.sampleRate = 1.0; // 100% of errors

          // Enable lifecycle breadcrumbs
          options.enableAppLifecycleBreadcrumbs = true;

          // Debug mode for development
          options.debug = _getEnvironment() == 'development';
        },
        appRunner: () => runApp(const SentryScreenshotWidget()),
      );

      _isInitialized = true;
      Logger.info('Sentry initialized successfully', tag: 'Sentry');
      Logger.info('Environment: ${_getEnvironment()}', tag: 'Sentry');
      Logger.info('Release: ${_getRelease()}', tag: 'Sentry');
    } catch (e) {
      Logger.error('Failed to initialize Sentry: $e', tag: 'Sentry');
      _isInitialized = false;
    }
  }

  /// Captures an exception with additional context
  ///
  /// Parameters:
  /// - [exception]: The exception to capture
  /// - [stackTrace]: Optional stack trace
  /// - [context]: Additional context information
  static void captureException(
    dynamic exception, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    if (!_isInitialized) {
      Logger.error('Exception (Sentry not initialized): $exception',
        tag: 'Sentry', error: exception, stackTrace: stackTrace);
      return;
    }

    try {
      Sentry.captureException(
        exception,
        stackTrace: stackTrace,
      );
      Logger.error('Captured exception: $exception', tag: 'Sentry');
    } catch (e) {
      Logger.error('Failed to capture exception: $e', tag: 'Sentry');
    }
  }

  /// Captures a message as an event
  ///
  /// Parameters:
  /// - [message]: The message to send
  /// - [level]: The severity level
  /// - [context]: Additional context
  static void captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? context,
  }) {
    if (!_isInitialized) {
      Logger.info('[$level] $message', tag: 'Sentry');
      return;
    }

    try {
      Sentry.captureMessage(
        message,
        level: level,
      );
      Logger.info('[$level] Captured message: $message', tag: 'Sentry');
    } catch (e) {
      Logger.error('Failed to capture message: $e', tag: 'Sentry');
    }
  }

  /// Sets the user context for subsequent events
  ///
  /// Parameters:
  /// - [userId]: The user's ID
  /// - [email]: The user's email
  /// - [username]: The user's username
  /// - [additionalData]: Any additional user data
  static void setUserContext({
    required String userId,
    String? email,
    String? username,
    Map<String, dynamic>? additionalData,
  }) {
    if (!_isInitialized) return;

    try {
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: userId, email: email, username: username));
      });
      Logger.info('Set user context: $userId', tag: 'Sentry');
    } catch (e) {
      Logger.error('Failed to set user context: $e', tag: 'Sentry');
    }
  }

  /// Sets the organization context for multi-tenant apps
  ///
  /// Parameters:
  /// - [organizationId]: The organization ID
  /// - [organizationName]: The organization name
  static void setOrganizationContext({
    required String organizationId,
    String? organizationName,
  }) {
    if (!_isInitialized) return;

    try {
      Sentry.configureScope((scope) {
        scope.setContexts(
          'organization',
          {
            'id': organizationId,
            if (organizationName != null) 'name': organizationName,
          },
        );
      });
      Logger.info('Set organization context: $organizationId', tag: 'Sentry');
    } catch (e) {
      Logger.error('Failed to set organization context: $e', tag: 'Sentry');
    }
  }

  /// Clears the user context
  static void clearUserContext() {
    if (!_isInitialized) return;

    try {
      Sentry.configureScope((scope) {
        scope.setUser(null);
      });
      Logger.info('Cleared user context', tag: 'Sentry');
    } catch (e) {
      Logger.error('Failed to clear user context: $e', tag: 'Sentry');
    }
  }

  /// Adds a breadcrumb for tracking the execution path
  ///
  /// Parameters:
  /// - [category]: The category of breadcrumb
  /// - [message]: The breadcrumb message
  /// - [data]: Additional data
  static void addBreadcrumb({
    required String category,
    required String message,
    Map<String, dynamic>? data,
  }) {
    if (!_isInitialized) return;

    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: category,
          data: data,
          message: message,
          level: SentryLevel.info,
        ),
      );
    } catch (e) {
      Logger.error('Failed to add breadcrumb: $e', tag: 'Sentry');
    }
  }

  /// Checks if Sentry is properly initialized
  static bool get isReady => _isInitialized;

  /// Gets the current configuration
  static Map<String, dynamic> get config => {
    'initialized': _isInitialized,
    'environment': _getEnvironment(),
    'release': _getRelease(),
    'dsn_configured': const String.fromEnvironment('SENTRY_DSN_FLUTTER', defaultValue: '').isNotEmpty,
  };

  // =============================================================================
  // PRIVATE HELPERS
  // =============================================================================

  /// Determines the environment from build configuration
  static String _getEnvironment() {
    // In production builds, this would be set via compile-time constants
    // For now, use a simple heuristic
    try {
      // Check if we're in debug mode
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        return 'development';
      }
      return 'production';
    } catch (_) {
      return 'production';
    }
  }

  /// Gets the release version
  static String _getRelease() {
    // This would typically come from pubspec.yaml version
    // In a real setup, this should be set at build time
    try {
      return const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: '1.2.0',
      );
    } catch (_) {
      return '1.2.0';
    }
  }
}

/// Placeholder widget for Sentry appRunner
class SentryScreenshotWidget extends StatelessWidget {
  const SentryScreenshotWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
