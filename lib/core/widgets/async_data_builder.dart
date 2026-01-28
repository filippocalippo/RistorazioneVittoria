import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../DesignSystem/design_tokens.dart';
import 'shimmer_loaders.dart';
import 'error_display.dart';

/// Unified async state builder widget
///
/// Provides consistent handling of loading, error, and data states
/// across all async operations in the app.
///
/// Example usage:
/// ```dart
/// AsyncDataBuilder(
///   value: menuProvider,
///   data: (items) => MenuGrid(items: items),
///   loading: () => MenuLoadingShimmer(),
///   loadingMessage: 'Caricamento menu...',
/// )
/// ```
class AsyncDataBuilder<T> extends ConsumerWidget {
  /// The async value to observe
  final AsyncValue<T> value;

  /// Builder for successful data state
  final Widget Function(T data) data;

  /// Custom loading widget (optional, uses default shimmer if not provided)
  final Widget Function()? loading;

  /// Custom error widget (optional, uses default error display if not provided)
  final Widget Function(Object error, StackTrace stack)? error;

  /// Widget to show when data is null (optional)
  final Widget? skipOnNull;

  /// Message to show during loading (optional)
  final String? loadingMessage;

  const AsyncDataBuilder({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.skipOnNull,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      data: (dataValue) {
        if (skipOnNull != null && dataValue == null) {
          return skipOnNull!;
        }
        return data(dataValue);
      },
      loading: () => loading != null
          ? loading!()
          : _DefaultLoading(message: loadingMessage),
      error: (err, stack) => error != null
          ? error!(err, stack)
          : ErrorDisplay(
              error: err,
              stackTrace: stack,
            ),
    );
  }
}

/// Default loading widget with centered spinner
class _DefaultLoading extends StatelessWidget {
  final String? message;

  const _DefaultLoading({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            SizedBox(height: AppSpacing.lg),
            Text(
              message!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Async data builder with shimmer loading placeholder
///
/// Uses shimmer loaders for a more polished loading experience.
/// Best for lists, grids, and card-based content.
class AsyncDataBuilderWithShimmer<T> extends ConsumerWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function()? shimmer;
  final Widget Function(Object error, StackTrace stack)? error;
  final Widget? skipOnNull;

  const AsyncDataBuilderWithShimmer({
    super.key,
    required this.value,
    required this.data,
    this.shimmer,
    this.error,
    this.skipOnNull,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      data: (dataValue) {
        if (skipOnNull != null && dataValue == null) {
          return skipOnNull!;
        }
        return data(dataValue);
      },
      loading: () => shimmer != null
          ? shimmer!()
          : const _DefaultShimmerLoading(),
      error: (err, stack) => error != null
          ? error!(err, stack)
          : ErrorDisplay(
              error: err,
              stackTrace: stack,
            ),
    );
  }
}

class _DefaultShimmerLoading extends StatelessWidget {
  const _DefaultShimmerLoading();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          SizedBox(height: AppSpacing.massive),
          MenuSectionShimmer(itemCount: 3),
          MenuSectionShimmer(itemCount: 2),
        ],
      ),
    );
  }
}
