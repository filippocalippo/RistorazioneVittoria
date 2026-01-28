import 'package:flutter/material.dart';
import '../../DesignSystem/design_tokens.dart';
import '../utils/constants.dart';
import '../exceptions/app_exceptions.dart';

/// Reusable error display widget
///
/// Provides consistent error UI across the app.
/// Handles different error types with appropriate messages.
///
/// Example usage:
/// ```dart
/// ErrorDisplay(
///   error: error,
///   stackTrace: stackTrace,
///   onRetry: () => ref.invalidate(provider),
/// )
/// ```
class ErrorDisplay extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final String? title;
  final String? message;

  const ErrorDisplay({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
    this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final errorMessage = message ?? _getUserFriendlyMessage(error);
    final errorTitle = title ?? _getDefaultTitle(error);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getErrorIcon(error),
                size: 40,
                color: AppColors.error,
              ),
            ),

            SizedBox(height: AppSpacing.xl),

            // Error title
            Text(
              errorTitle,
              style: AppTypography.titleMedium,
            ),

            SizedBox(height: AppSpacing.sm),

            // Error message
            Text(
              errorMessage,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            // Retry button
            if (onRetry != null) ...[
              SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ],

            // Debug mode: show full error details
            if (const bool.fromEnvironment('dart.vm.product') == false &&
                stackTrace != null) ...[
              SizedBox(height: AppSpacing.xl),
              GestureDetector(
                onTap: () => _showErrorDetails(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bug_report_outlined,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        'Debug',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getDefaultTitle(Object error) {
    if (error is NetworkException) return 'Errore di connessione';
    if (error is AuthException) return 'Errore di autenticazione';
    if (error is ValidationException) return 'Dati non validi';
    if (error is PermissionException) return 'Permesso negato';
    if (error is NotFoundException) return 'Non trovato';
    if (error is StorageException) return 'Errore di archiviazione';
    return "Si è verificato un errore";
  }

  IconData _getErrorIcon(Object error) {
    if (error is NetworkException) return Icons.wifi_off_rounded;
    if (error is AuthException) return Icons.lock_rounded;
    if (error is ValidationException) return Icons.error_outline_rounded;
    if (error is PermissionException) return Icons.block_rounded;
    if (error is NotFoundException) return Icons.search_off_rounded;
    if (error is StorageException) return Icons.cloud_off_rounded;
    return Icons.error_outline_rounded;
  }

  String _getUserFriendlyMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }
    if (error.toString().contains('SocketException')) {
      return ErrorMessages.networkError;
    }
    if (error.toString().contains('TimeoutException')) {
      return 'Timeout della richiesta. Riprova.';
    }
    return ErrorMessages.unknownError;
  }

  void _showErrorDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Details'),
        content: SingleChildScrollView(
          child: SelectableText(
            'Error: $error\n\nStackTrace:\n$stackTrace',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }
}

/// Compact error display for inline errors
class CompactErrorDisplay extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const CompactErrorDisplay({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
          if (onRetry != null)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: onRetry,
              color: AppColors.error,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

/// Empty state display for when data is available but empty
class EmptyStateDisplay extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyStateDisplay({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: AppTypography.titleMedium,
            ),
            if (message != null) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
