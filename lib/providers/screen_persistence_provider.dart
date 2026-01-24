import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/constants.dart';

part 'screen_persistence_provider.g.dart';

/// Provider for persisting and retrieving the last viewed screen
@riverpod
class ScreenPersistence extends _$ScreenPersistence {
  static const String _lastScreenKey = 'last_viewed_screen';

  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastScreenKey);
  }

  /// Save the current screen route
  Future<void> saveCurrentScreen(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastScreenKey, route);
    state = AsyncValue.data(route);
  }

  /// Clear the saved screen (e.g., on logout)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastScreenKey);
    state = const AsyncValue.data(null);
  }

  /// Get the initial route based on user role and last viewed screen
  String getInitialRoute({
    required String? userRole,
    required String? lastScreen,
  }) {
    // Define valid routes for each role/shell
    final managerRoutes = [
      RouteNames.dashboard,
      RouteNames.managerOrders,
      RouteNames.managerMenu,
      RouteNames.settings,
      RouteNames.staffManagement,
      RouteNames.assignDelivery,
      RouteNames.cashierOrder,
      RouteNames.bulkOperations,
    ];

    final customerRoutes = [
      RouteNames.menu,
      RouteNames.customerProfile,
      RouteNames.cart,
    ];

    final kitchenRoutes = [RouteNames.kitchenOrders];

    final deliveryRoutes = [RouteNames.deliveryReady];

    // If we have a saved screen, use it if valid for the user's role
    if (lastScreen != null && lastScreen.isNotEmpty) {
      // Manager can access manager routes AND delivery routes
      if (userRole == 'manager') {
        if (managerRoutes.contains(lastScreen) ||
            deliveryRoutes.contains(lastScreen) ||
            kitchenRoutes.contains(lastScreen)) {
          return lastScreen;
        }
      }

      // Delivery users can access delivery and customer routes
      if (userRole == 'delivery' &&
          (deliveryRoutes.contains(lastScreen) ||
              customerRoutes.contains(lastScreen))) {
        return lastScreen;
      }

      // Customer can access customer routes
      if (userRole == 'customer' && customerRoutes.contains(lastScreen)) {
        return lastScreen;
      }

      // Kitchen can access kitchen routes
      if (userRole == 'kitchen' && kitchenRoutes.contains(lastScreen)) {
        return lastScreen;
      }
    }

    // Fallback to role-based default
    if (userRole == 'delivery') {
      return RouteNames.deliveryReady;
    } else if (userRole == 'customer') {
      return RouteNames.menu;
    } else if (userRole == 'manager') {
      return RouteNames.dashboard;
    } else if (userRole == 'kitchen') {
      return RouteNames.kitchenOrders;
    }

    return RouteNames.menu;
  }
}
