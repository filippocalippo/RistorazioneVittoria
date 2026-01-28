import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../DesignSystem/design_tokens.dart';
import 'error_display.dart';

/// Error boundary wrapper for Flutter widgets
///
/// Catches Flutter errors and displays a consistent error UI.
/// Use this to wrap sections of your app that may throw errors.
///
/// Example usage:
/// ```dart
/// ErrorBoundary(
///   child: MyWidget(),
///   errorBuilder: (error, stack) => ErrorDisplay(error: error),
/// )
/// ```
class ErrorBoundary extends StatelessWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace stack)? errorBuilder;

  const ErrorBoundary({super.key, required this.child, this.errorBuilder});

  @override
  Widget build(BuildContext context) {
    return RunErrorWidget(errorBuilder: errorBuilder, child: child);
  }
}

/// Internal widget that catches errors
class RunErrorWidget extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace stack)? errorBuilder;

  const RunErrorWidget({super.key, required this.child, this.errorBuilder});

  @override
  State<RunErrorWidget> createState() => _RunErrorWidgetState();
}

class _RunErrorWidgetState extends State<RunErrorWidget> {
  Object? _caughtError;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    // Store original error handler
    _originalOnError = FlutterError.onError;
    // Set new error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _caughtError = details.exception;
              _stackTrace = details.stack;
            });
          }
        });
      }
      // Also call original handler
      _originalOnError?.call(details);
    };
  }

  static void Function(FlutterErrorDetails)? _originalOnError;

  @override
  void dispose() {
    // Restore original error handler BEFORE calling super.dispose()
    // to avoid accessing widget ancestors during tree teardown
    final originalHandler = _originalOnError;
    _originalOnError = null; // Clear reference to prevent callbacks
    FlutterError.onError = originalHandler ?? FlutterError.dumpErrorToConsole;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_caughtError != null) {
      final stack = _stackTrace ?? StackTrace.empty;
      return widget.errorBuilder != null
          ? widget.errorBuilder!(_caughtError!, stack)
          : _DefaultErrorBoundaryDisplay(
              error: _caughtError!,
              stackTrace: stack,
            );
    }

    return widget.child;
  }
}

class _DefaultErrorBoundaryDisplay extends StatelessWidget {
  final Object error;
  final StackTrace stackTrace;

  const _DefaultErrorBoundaryDisplay({
    required this.error,
    required this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Errore'),
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
      ),
      body: ErrorDisplay(
        error: error,
        stackTrace: stackTrace,
        title: 'Errore di rendering',
      ),
    );
  }
}

/// Consumer error boundary that also logs errors
///
/// Extends ErrorBoundary with error logging capabilities.
/// Integrates with error reporting service.
class ErrorBoundaryWithLogger extends ConsumerStatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace stack)? errorBuilder;
  final String? contextTag;

  const ErrorBoundaryWithLogger({
    super.key,
    required this.child,
    this.errorBuilder,
    this.contextTag,
  });

  @override
  ConsumerState<ErrorBoundaryWithLogger> createState() =>
      _ErrorBoundaryWithLoggerState();
}

class _ErrorBoundaryWithLoggerState
    extends ConsumerState<ErrorBoundaryWithLogger> {
  Object? _caughtError;
  StackTrace? _stackTrace;
  void Function(FlutterErrorDetails)? _originalOnError;

  @override
  void initState() {
    super.initState();
    // Store original error handler
    _originalOnError = FlutterError.onError;
    // Initialize Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      // Schedule the state update for the next frame to avoid "Build scheduled during frame" errors
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _caughtError = details.exception;
              _stackTrace = details.stack;
            });
          }
        });
      }

      // Log error
      _logError(details.exception, details.stack);
      // Also call original handler
      _originalOnError?.call(details);
    };
  }

  void _logError(Object error, StackTrace? stack) {
    // In production, send to error reporting service
    // For now, just print to console
    debugPrint('[ErrorBoundary] ${widget.contextTag ?? "Unknown"}: $error');
    if (stack != null) {
      debugPrint(stack.toString());
    }

    // TODO: Integrate with error_reporter.dart
    // ref.read(errorReporterProvider.notifier).reportError(
    //   error,
    //   stack,
    //   context: widget.contextTag,
    // );
  }

  @override
  void dispose() {
    // Restore original error handler BEFORE calling super.dispose()
    // to avoid accessing widget ancestors during tree teardown
    final originalHandler = _originalOnError;
    _originalOnError = null; // Clear reference to prevent callbacks
    FlutterError.onError = originalHandler ?? FlutterError.dumpErrorToConsole;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_caughtError != null) {
      final stack = _stackTrace ?? StackTrace.empty;
      return widget.errorBuilder != null
          ? widget.errorBuilder!(_caughtError!, stack)
          : _DefaultErrorBoundaryDisplay(
              error: _caughtError!,
              stackTrace: stack,
            );
    }

    return widget.child;
  }
}

/// Async error boundary for provider errors
///
/// Catches errors from async operations in providers.
class AsyncErrorBoundary<T> extends ConsumerWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function(Object error, StackTrace stack)? error;
  final Widget? loading;
  final VoidCallback? onRetry;

  const AsyncErrorBoundary({
    super.key,
    required this.value,
    required this.data,
    this.error,
    this.loading,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      data: data,
      loading: () =>
          loading ??
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, stack) => error != null
          ? error!(err, stack)
          : ErrorDisplay(error: err, stackTrace: stack, onRetry: onRetry),
    );
  }
}

