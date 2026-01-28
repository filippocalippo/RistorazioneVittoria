import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../DesignSystem/design_tokens.dart';
import '../providers/network_status_provider.dart';

/// Offline status banner widget
///
/// Displays a banner at the top of the screen when the device is offline.
/// Automatically shows/hides based on network connectivity.
///
/// Usage:
/// ```dart
/// Material(
///   child: Column(
///     children: [
///       OfflineBanner(),
///       // Rest of your app
///     ],
///   ),
/// )
/// ```
class OfflineBanner extends ConsumerWidget {
  final bool showWhenOnline;
  final String? offlineMessage;
  final String? onlineMessage;
  final Color? offlineColor;
  final Color? onlineColor;

  const OfflineBanner({
    super.key,
    this.showWhenOnline = false,
    this.offlineMessage,
    this.onlineMessage,
    this.offlineColor,
    this.onlineColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Temporarily disabled due to unreliable connectivity detection
    // The connectivity_plus package often returns false negatives
    // Real API failures will show proper error messages instead
    return const SizedBox.shrink();

    /* ENABLED WHEN CONNECTIVITY IS RELIABLE:
    final networkStateAsync = ref.watch(networkStatusProvider);

    return networkStateAsync.when(
      data: (networkState) {
        final isOnline = networkState.isOnline;

        // Don't show if online and showWhenOnline is false
        if (isOnline && !showWhenOnline) {
          return const SizedBox.shrink();
        }

        final message = isOnline
            ? (onlineMessage ?? 'Connesso - ${networkState.connectionName}')
            : (offlineMessage ?? 'Offline - verifica la connessione');

        final backgroundColor = isOnline
            ? (onlineColor ?? AppColors.success)
            : (offlineColor ?? AppColors.error);

        return Container(
          width: double.infinity,
          color: backgroundColor,
          padding: EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  message,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
    */
  }
}

/// Compact offline indicator for use in app bars
///
/// Shows a small indicator dot instead of a full banner.
/// Best for use in AppBar or BottomNavigationBar.
class OfflineIndicator extends ConsumerWidget {
  final double size;
  final EdgeInsetsGeometry? padding;

  const OfflineIndicator({
    super.key,
    this.size = 8,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkStateAsync = ref.watch(networkStatusProvider);

    return networkStateAsync.when(
      data: (networkState) {
        // Don't show anything when online
        if (networkState.isOnline) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: padding ?? EdgeInsets.all(AppSpacing.sm),
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Network-aware widget wrapper
///
/// Shows one widget when online, another when offline.
///
/// Usage:
/// ```dart
/// NetworkAware(
///   online: OnlineContent(),
///   offline: OfflinePlaceholder(),
/// )
/// ```
class NetworkAware extends ConsumerWidget {
  final Widget online;
  final Widget offline;
  final Widget? loading;

  const NetworkAware({
    super.key,
    required this.online,
    required this.offline,
    this.loading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkStateAsync = ref.watch(networkStatusProvider);

    return networkStateAsync.when(
      data: (networkState) {
        return networkState.isOnline ? online : offline;
      },
      loading: () => loading ??
          Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
      error: (_, _) => offline,
    );
  }
}

/// No internet connection placeholder widget
///
/// Displays a friendly "no connection" message with illustration.
/// Use with [NetworkAware] or on its own.
class NoConnectionPlaceholder extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoConnectionPlaceholder({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // WiFi off icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 50,
                color: AppColors.textTertiary,
              ),
            ),

            SizedBox(height: AppSpacing.xl),

            Text(
              'Nessuna connessione',
              style: AppTypography.titleLarge,
            ),

            SizedBox(height: AppSpacing.md),

            Text(
              'Verifica la tua connessione internet e riprova',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

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
          ],
        ),
      ),
    );
  }
}
