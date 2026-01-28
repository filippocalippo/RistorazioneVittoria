import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/connectivity_service.dart';
import '../utils/logger.dart';

part 'network_status_provider.g.dart';

/// Provider for the connectivity service instance
@riverpod
ConnectivityService connectivityService(Ref ref) {
  return ConnectivityService();
}

/// Network status provider
///
/// Provides real-time network connectivity status.
/// Automatically updates when connectivity changes.
///
/// Usage:
/// ```dart
/// final networkState = ref.watch(networkStatusProvider);
/// networkState.when(
///   data: (state) {
///     if (!state.isOnline) {
///       return OfflineBanner();
///     }
///     return OnlineContent();
///   },
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => ErrorWidget(err),
/// );
/// ```
@riverpod
class NetworkStatus extends _$NetworkStatus {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  Future<NetworkState> build() async {
    final service = ref.watch(connectivityServiceProvider);

    // Perform initial connectivity check
    Logger.debug(
      'NetworkStatus: Starting initial connectivity check',
      tag: 'NetworkStatus',
    );
    final isConnected = await service.isConnected;
    final results = await service.connectivityResults;

    final initialState = NetworkState(
      isOnline: isConnected,
      connectionTypes: results,
    );

    Logger.debug(
      'NetworkStatus: Initial state - ${initialState.toString()}',
      tag: 'NetworkStatus',
    );

    // Listen to connectivity changes
    _startListening(service);

    // Cleanup on dispose
    ref.onDispose(() {
      _subscription?.cancel();
      Logger.debug('NetworkStatus: Disposed', tag: 'NetworkStatus');
    });

    return initialState;
  }

  void _startListening(ConnectivityService service) {
    try {
      _subscription = service.onConnectivityChanged.listen(
        (results) {
          // Assume online if network interface is up
          // The actual API calls will determine if there's real connectivity
          final isOnline = results.contains(ConnectivityResult.none) == false;

          final newState = NetworkState(
            isOnline: isOnline,
            connectionTypes: results,
          );

          Logger.debug(
            'NetworkStatus: Connectivity changed - ${newState.toString()}',
            tag: 'NetworkStatus',
          );

          // Update state
          state = AsyncValue.data(newState);
        },
        onError: (error) {
          Logger.error(
            'NetworkStatus: Error listening to connectivity changes - $error',
            tag: 'NetworkStatus',
            error: error,
          );
          // Keep existing state on error - don't assume offline
        },
      );
    } catch (e) {
      Logger.error(
        'NetworkStatus: Failed to initialize connectivity listener - $e',
        tag: 'NetworkStatus',
        error: e,
      );
    }
  }

  /// Manually refresh the network status
  Future<void> refresh() async {
    final service = ref.read(connectivityServiceProvider);
    state = const AsyncValue.loading();

    try {
      final isConnected = await service.isConnected;
      final results = await service.connectivityResults;

      state = AsyncValue.data(
        NetworkState(isOnline: isConnected, connectionTypes: results),
      );
    } catch (e, stack) {
      Logger.error(
        'NetworkStatus: Failed to refresh - $e',
        tag: 'NetworkStatus',
        error: e,
        stackTrace: stack,
      );
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Convenience provider to check if device is online
///
/// Returns null while loading, true/false once determined.
@riverpod
Future<bool> isOnline(Ref ref) async {
  final networkState = await ref.watch(networkStatusProvider.future);
  return networkState.isOnline;
}

/// Convenience provider to get connection type
///
/// Returns the primary connection type (wifi, mobile, etc.)
@riverpod
Future<ConnectivityResult> connectionType(Ref ref) async {
  final networkState = await ref.watch(networkStatusProvider.future);
  return networkState.primaryType;
}

/// Stream provider for real-time connectivity updates
///
/// Emits a new value whenever connectivity changes.
/// Use this for reactive UI that needs to respond immediately.
@riverpod
Stream<NetworkState> networkStatusStream(Ref ref) {
  final service = ref.watch(connectivityServiceProvider);

  return service.onConnectivityChanged.map((results) {
    final isOnline = results.contains(ConnectivityResult.none) == false;
    return NetworkState(isOnline: isOnline, connectionTypes: results);
  });
}
