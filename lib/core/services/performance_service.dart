import 'dart:async';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'sentry_service.dart';
import '../utils/logger.dart';

/// Performance Service
///
/// Tracks API calls, database queries, and other operations for performance monitoring.
/// Integrates with Sentry for distributed tracing and performance analysis.
///
/// Part of Section 8.2 Backend Production Readiness
class PerformanceService {
  static const _edgeFunctionThresholdMs = 3000;
  static const _databaseQueryThresholdMs = 500;

  /// Tracks an API call to an edge function
  ///
  /// Parameters:
  /// - [functionName]: The name of the edge function
  /// - [operation]: The function to track
  /// - [tags]: Optional tags for filtering
  ///
  /// Returns the result of the operation
  static Future<T> trackApiCall<T>({
    required String functionName,
    required Future<T> Function() operation,
    Map<String, String>? tags,
  }) async {
    final transaction = Sentry.startTransaction(
      functionName,
      'edge_function',
      startTimestamp: DateTime.now(),
    );

    final span = transaction.startChild(
      'function.execution',
      description: functionName,
    );

    tags ??= {};
    tags['function'] = functionName;

    try {
      // Add breadcrumb
      if (SentryService.isReady) {
        SentryService.addBreadcrumb(
          category: 'api',
          message: 'Calling edge function: $functionName',
          data: tags,
        );
      }

      final startTime = DateTime.now();
      final result = await operation();
      final duration = DateTime.now().difference(startTime);

      await span.finish();

      // Log if slow
      if (duration.inMilliseconds > _edgeFunctionThresholdMs) {
        Logger.warning(
          'Slow edge function: $functionName took ${duration.inMilliseconds}ms',
          tag: 'Performance',
        );
      }

      await transaction.finish(
        status: const SpanStatus.ok(),
      );

      return result;
    } catch (error, stackTrace) {
      await span.finish(status: const SpanStatus.internalError());

      await transaction.finish(
        status: const SpanStatus.unknownError(),
      );

      // Capture exception with context
      if (SentryService.isReady) {
        SentryService.captureException(
          error,
          stackTrace: stackTrace,
          context: {
            'function': functionName,
            'duration_ms': DateTime.now()
                .difference(transaction.startTimestamp)
                .inMilliseconds,
          },
        );
      }

      rethrow;
    }
  }

  /// Tracks a database query
  ///
  /// Parameters:
  /// - [table]: The table being queried
  /// - [operation]: The operation type (select, insert, update, delete)
  /// - [query]: The query function
  ///
  /// Returns the query result
  static Future<T> trackDatabaseQuery<T>({
    required String table,
    required String operation,
    required Future<T> Function() query,
  }) async {
    final transaction = Sentry.startTransaction(
      '$operation on $table',
      'db.query',
      startTimestamp: DateTime.now(),
    );

    final span = transaction.startChild(
      'db.query',
      description: '$operation: $table',
    );

    try {
      final startTime = DateTime.now();
      final result = await query();
      final duration = DateTime.now().difference(startTime);

      await span.finish();

      // Log if slow
      if (duration.inMilliseconds > _databaseQueryThresholdMs) {
        Logger.warning(
          'Slow database query: $operation on $table took ${duration.inMilliseconds}ms',
          tag: 'Performance',
        );
      }

      await transaction.finish(
        status: const SpanStatus.ok(),
      );

      return result;
    } catch (error, stackTrace) {
      await span.finish(status: const SpanStatus.internalError());

      await transaction.finish(
        status: const SpanStatus.unknownError(),
      );

      // Capture exception with context
      if (SentryService.isReady) {
        SentryService.captureException(
          error,
          stackTrace: stackTrace,
          context: {
            'table': table,
            'operation': operation,
          },
        );
      }

      rethrow;
    }
  }

  /// Tracks a custom operation
  ///
  /// Parameters:
  /// - [operation]: The operation name
  /// - [operation]: The function to track
  /// - [category]: Optional category (default: 'custom')
  /// - [description]: Optional description
  ///
  /// Returns the result of the operation
  static Future<T> trackOperation<T>({
    required String operation,
    required Future<T> Function() fn,
    String category = 'custom',
    String? description,
  }) async {
    final transaction = Sentry.startTransaction(
      description ?? operation,
      category,
      startTimestamp: DateTime.now(),
    );

    try {
      final result = await fn();

      await transaction.finish(
        status: const SpanStatus.ok(),
      );

      return result;
    } catch (error, stackTrace) {
      await transaction.finish(
        status: const SpanStatus.unknownError(),
      );

      if (SentryService.isReady) {
        SentryService.captureException(
          error,
          stackTrace: stackTrace,
          context: {'operation': operation},
        );
      }

      rethrow;
    }
  }

  /// Measures the duration of a synchronous operation
  ///
  /// Parameters:
  /// - [name]: The operation name
  /// - [fn]: The function to measure
  ///
  /// Returns the result of the operation
  static T measureSync<T>({
    required String name,
    required T Function() fn,
  }) {
    final stopwatch = Stopwatch()..start();
    try {
      final result = fn();
      stopwatch.stop();

      final duration = stopwatch.elapsedMilliseconds;
      if (duration > 100) {
        // Log operations taking more than 100ms
        Logger.info(
          '$name took ${duration}ms',
          tag: 'Performance',
        );
      }

      return result;
    } finally {
      stopwatch.stop();
    }
  }

  /// Starts a performance transaction manually
  ///
  /// Use this for complex operations with multiple spans
  ///
  /// Parameters:
  /// - [name]: The transaction name
  /// - [operation]: The operation type
  ///
  /// Returns a ISentryTransaction that must be finished manually
  static dynamic startTransaction({
    required String name,
    String operation = 'custom',
  }) {
    if (!SentryService.isReady) {
      return _DummyTransaction();
    }

    return Sentry.startTransaction(
      name,
      operation,
      startTimestamp: DateTime.now(),
    );
  }

  /// Adds a child span to a transaction
  ///
  /// Parameters:
  /// - [transaction]: The parent transaction
  /// - [operation]: The span operation type
  /// - [description]: The span description
  ///
  /// Returns a ISpan that must be finished manually
  static ISentrySpan? startSpan({
    required dynamic transaction,
    required String operation,
    required String description,
  }) {
    // Try to call startChild on the transaction
    try {
      return transaction.startChild(
        operation,
        description: description,
      );
    } catch (_) {
      return null;
    }
  }

  /// Tracks a screen navigation
  ///
  /// Parameters:
  /// - [fromScreen]: The screen being navigated from
  /// - [toScreen]: The screen being navigated to
  static void trackNavigation({
    required String fromScreen,
    required String toScreen,
  }) {
    if (SentryService.isReady) {
      SentryService.addBreadcrumb(
        category: 'navigation',
        message: 'Navigate from $fromScreen to $toScreen',
        data: {
          'from': fromScreen,
          'to': toScreen,
        },
      );
    }
  }

  /// Tracks a user interaction (button tap, etc.)
  ///
  /// Parameters:
  /// - [action]: The action performed (e.g., 'button_tap')
  /// - [target]: The target of the action (e.g., 'submit_button')
  /// - [context]: Additional context
  static void trackInteraction({
    required String action,
    required String target,
    Map<String, dynamic>? context,
  }) {
    if (SentryService.isReady) {
      SentryService.addBreadcrumb(
        category: 'user',
        message: '$action on $target',
        data: {
          'action': action,
          'target': target,
          ...?context,
        },
      );
    }
  }

  /// Gets performance metrics summary
  ///
  /// Returns a summary of recent performance metrics
  static Map<String, dynamic> getMetricsSummary() {
    // This would typically pull from a metrics store
    // For now, return a placeholder
    return {
      'edge_function_calls': 0,
      'avg_edge_function_duration_ms': 0,
      'slow_edge_function_calls': 0,
      'database_queries': 0,
      'avg_database_query_duration_ms': 0,
      'slow_database_queries': 0,
    };
  }

  /// Checks if the app is performing well
  ///
  /// Returns true if performance is within acceptable thresholds
  static bool checkPerformanceHealth() {
    final metrics = getMetricsSummary();

    // Check edge function performance
    if (metrics['slow_edge_function_calls'] > 10) {
      return false;
    }

    // Check database performance
    if (metrics['slow_database_queries'] > 20) {
      return false;
    }

    return true;
  }
}

/// Dummy transaction for when Sentry is not initialized
class _DummyTransaction {
  DateTime startTimestamp = DateTime.now();

  Future<void> finish({SpanStatus? status}) async {
    // No-op when Sentry is not ready
  }

  ISentrySpan? startChild(String operation, {String? description}) {
    return null;
  }
}

// Re-export types
typedef ISpan = ISentrySpan;
