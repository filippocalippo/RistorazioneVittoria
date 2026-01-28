import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../utils/logger.dart';

/// Network connectivity monitoring service
///
/// Provides real-time network status monitoring.
/// Listens to connectivity changes and provides current state.
///
/// Usage:
/// ```dart
/// final service = ref.read(connectivityServiceProvider);
/// final isConnected = await service.isConnected;
/// service.onConnectivityChanged.listen((result) {
///   print('Connection changed: $result');
/// });
/// ```
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Stream of connectivity changes
  ///
  /// Emits a list of ConnectivityResult whenever the connection status changes.
  /// Multiple connections can be active simultaneously (e.g., wifi and vpn).
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// Check if device currently has network connectivity
  ///
  /// Returns true if any connection is available (wifi, mobile, ethernet, etc.)
  /// Returns false if no connections are active.
  Future<bool> get isConnected async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasConnection = results.contains(ConnectivityResult.none) == false;
      Logger.debug('Connectivity check: $hasConnection (${results.join(', ')})', tag: 'Connectivity');
      return hasConnection;
    } catch (e) {
      Logger.error('Failed to check connectivity: $e', tag: 'Connectivity', error: e);
      // Return true (assume connected) on error to avoid false offline
      return true;
    }
  }

  /// Get the current connectivity result list
  ///
  /// Returns a list of active connections.
  /// Returns [ConnectivityResult.none] if no connection is available.
  Future<List<ConnectivityResult>> get connectivityResults async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results;
    } catch (e) {
      Logger.error('Failed to get connectivity results: $e', tag: 'Connectivity', error: e);
      return [ConnectivityResult.none];
    }
  }

  /// Get the primary connection type
  ///
  /// Returns the first (primary) connection type.
  /// Prefer [connectivityResults] for full list.
  Future<ConnectivityResult> get primaryConnectionType async {
    final results = await connectivityResults;
    return results.firstOrNull ?? ConnectivityResult.none;
  }

  /// Check if currently on WiFi
  Future<bool> get isOnWifi async {
    final results = await connectivityResults;
    return results.contains(ConnectivityResult.wifi);
  }

  /// Check if currently on mobile data
  Future<bool> get isOnMobile async {
    final results = await connectivityResults;
    return results.contains(ConnectivityResult.mobile);
  }

  /// Check if currently on ethernet
  Future<bool> get isOnEthernet async {
    final results = await connectivityResults;
    return results.contains(ConnectivityResult.ethernet);
  }

  /// Check if currently on VPN
  Future<bool> get isOnVpn async {
    final results = await connectivityResults;
    return results.contains(ConnectivityResult.vpn);
  }

  /// Check if device supports bluetooth (for reference, not for connectivity)
  Future<bool> get isBluetoothAvailable async {
    final results = await connectivityResults;
    return results.contains(ConnectivityResult.bluetooth);
  }

  /// Get human-readable connection name
  Future<String> getConnectionName() async {
    final results = await connectivityResults;

    if (results.contains(ConnectivityResult.wifi)) return 'WiFi';
    if (results.contains(ConnectivityResult.mobile)) return 'Dati mobili';
    if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    if (results.contains(ConnectivityResult.vpn)) return 'VPN';
    if (results.contains(ConnectivityResult.bluetooth)) return 'Bluetooth';
    if (results.contains(ConnectivityResult.none)) return 'Offline';
    if (results.contains(ConnectivityResult.other)) return 'Altro';

    return 'Sconosciuto';
  }

  /// Create a subscription that calls [onChange] when connectivity changes
  StreamSubscription<List<ConnectivityResult>> listenToConnectivity(
    void Function(List<ConnectivityResult> results) onChange,
  ) {
    return onConnectivityChanged.listen((results) {
      Logger.debug('Connectivity changed to: ${results.join(', ')}', tag: 'Connectivity');
      onChange(results);
    });
  }
}

/// Network state data class
///
/// Represents the current network connectivity status.
class NetworkState {
  final bool isOnline;
  final List<ConnectivityResult> connectionTypes;
  final DateTime updatedAt;

  NetworkState({
    required this.isOnline,
    required this.connectionTypes,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Get the primary connection type
  ConnectivityResult get primaryType =>
      connectionTypes.firstOrNull ?? ConnectivityResult.none;

  /// Check if on WiFi
  bool get isOnWifi => connectionTypes.contains(ConnectivityResult.wifi);

  /// Check if on mobile
  bool get isOnMobile => connectionTypes.contains(ConnectivityResult.mobile);

  /// Check if on ethernet
  bool get isOnEthernet => connectionTypes.contains(ConnectivityResult.ethernet);

  /// Check if on VPN
  bool get isOnVpn => connectionTypes.contains(ConnectivityResult.vpn);

  /// Get human-readable connection name
  String get connectionName {
    if (isOnWifi) return 'WiFi';
    if (isOnMobile) return 'Dati mobili';
    if (isOnEthernet) return 'Ethernet';
    if (isOnVpn) return 'VPN';
    if (!isOnline) return 'Offline';
    return 'Altro';
  }

  @override
  String toString() {
    return 'NetworkState(isOnline: $isOnline, types: ${connectionTypes.join(', ')})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkState &&
        other.isOnline == isOnline &&
        _listEquals(other.connectionTypes, connectionTypes);
  }

  @override
  int get hashCode => Object.hash(isOnline, connectionTypes.length);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  NetworkState copyWith({
    bool? isOnline,
    List<ConnectivityResult>? connectionTypes,
    DateTime? updatedAt,
  }) {
    return NetworkState(
      isOnline: isOnline ?? this.isOnline,
      connectionTypes: connectionTypes ?? this.connectionTypes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
