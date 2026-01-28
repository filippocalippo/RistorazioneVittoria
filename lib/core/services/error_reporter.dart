import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

/// Error reporting service
///
/// Collects and reports errors for monitoring and debugging.
/// In production, this would integrate with services like Sentry.
///
/// Usage:
/// ```dart
/// final reporter = ref.read(errorReporterProvider.notifier);
/// await reporter.reportError(error, stackTrace, context: 'user_action');
/// ```
class ErrorReporter {
  /// List of reported errors (in-memory only, cleared on restart)
  final List<ErrorReport> _errors = [];

  /// Maximum number of errors to keep in memory
  static const int _maxErrorsInMemory = 100;

  /// Get all reported errors
  List<ErrorReport> get errors => List.unmodifiable(_errors);

  /// Clear all errors from memory
  void clearErrors() {
    _errors.clear();
    Logger.debug('Error history cleared', tag: 'ErrorReporter');
  }

  /// Report an error
  ///
  /// [error] - The error object
  /// [stackTrace] - The stack trace
  /// [context] - Optional context string (e.g., 'menu_screen', 'place_order')
  /// [fatal] - Whether this is a fatal error
  /// [data] - Additional data to attach to the error report
  Future<void> reportError(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    bool fatal = false,
    Map<String, dynamic>? data,
  }) async {
    final report = ErrorReport(
      error: error,
      stackTrace: stackTrace,
      context: context,
      fatal: fatal,
      data: data,
      timestamp: DateTime.now(),
    );

    // Add to in-memory list
    _errors.add(report);
    if (_errors.length > _maxErrorsInMemory) {
      _errors.removeAt(0);
    }

    // Log the error
    _logErrorReport(report);

    // In production, send to error reporting service (Sentry, etc.)
    if (kReleaseMode) {
      await _sendToRemoteService(report);
    }
  }

  void _logErrorReport(ErrorReport report) {
    final logLevel = report.fatal ? 'CRITICAL' : 'ERROR';
    final contextStr = report.context != null ? ' [${report.context}]' : '';

    Logger.error(
      '$logLevel$contextStr: ${report.error}',
      tag: 'ErrorReporter',
      error: report.error,
      stackTrace: report.stackTrace,
    );

    if (report.data != null && report.data!.isNotEmpty) {
      Logger.debug(
        'Error data: ${report.data}',
        tag: 'ErrorReporter',
      );
    }
  }

  Future<void> _sendToRemoteService(ErrorReport report) async {
    // TODO: Integrate with Sentry or similar service
    // Example:
    // await Sentry.captureException(
    //   report.error,
    //   stackTrace: report.stackTrace,
    //   hint: Hint.withMap({
    //     'context': report.context,
    //     'fatal': report.fatal,
    //     ...?report.data,
    //   }),
    // );
  }

  /// Report a non-fatal warning
  void reportWarning(
    String message, {
    String? context,
    Map<String, dynamic>? data,
  }) {
    final contextStr = context != null ? ' [$context]' : '';
    Logger.warning('WARNING$contextStr: $message', tag: 'ErrorReporter');

    if (data != null && data.isNotEmpty) {
      Logger.debug('Warning data: $data', tag: 'ErrorReporter');
    }
  }

  /// Get errors by context
  List<ErrorReport> getErrorsByContext(String context) {
    return _errors.where((e) => e.context == context).toList();
  }

  /// Get fatal errors
  List<ErrorReport> get fatalErrors =>
      _errors.where((e) => e.fatal).toList();

  /// Get error statistics
  ErrorStats getStats() {
    return ErrorStats(
      totalErrors: _errors.length,
      fatalErrors: fatalErrors.length,
      uniqueContexts: _errors.map((e) => e.context).whereType<String>().toSet().length,
    );
  }
}

/// Error report data class
class ErrorReport {
  final Object error;
  final StackTrace? stackTrace;
  final String? context;
  final bool fatal;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  ErrorReport({
    required this.error,
    this.stackTrace,
    this.context,
    required this.fatal,
    this.data,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'ErrorReport(context: $context, fatal: $fatal, error: $error, time: $timestamp)';
  }
}

/// Error statistics
class ErrorStats {
  final int totalErrors;
  final int fatalErrors;
  final int uniqueContexts;

  ErrorStats({
    required this.totalErrors,
    required this.fatalErrors,
    required this.uniqueContexts,
  });

  @override
  String toString() {
    return 'ErrorStats(total: $totalErrors, fatal: $fatalErrors, contexts: $uniqueContexts)';
  }
}

/// Global error reporter instance
/// Use this provider to access the error reporter throughout the app
final errorReporterProvider = Provider<ErrorReporter>((ref) {
  return ErrorReporter();
});
