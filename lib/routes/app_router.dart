import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/screen_persistence_provider.dart';
import '../providers/organization_provider.dart';
import '../core/utils/enums.dart';
import '../core/utils/constants.dart';
import '../core/models/user_model.dart';
import '../core/utils/logger.dart';
import '../core/widgets/app_shell.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/onboarding/screens/connect_screen.dart';
import '../features/onboarding/screens/organization_preview_screen.dart';
import '../features/onboarding/screens/organization_switcher_screen.dart';
import '../features/customer/screens/menu_screen.dart';
import '../features/customer/screens/current_order_screen.dart';
import '../features/customer/screens/cart_screen.dart';
import '../features/customer/screens/checkout_time_selection_screen.dart';
import '../features/customer/screens/checkout_screen.dart';
import '../features/customer/screens/profile_screen.dart';
import '../core/models/user_address_model.dart';
import '../features/manager/screens/dashboard_screen.dart';
import '../features/manager/screens/manager_menu_screen.dart';
import '../features/manager/screens/orders_screen.dart';
import '../features/manager/screens/settings_screen.dart';
import '../features/manager/screens/size_variants_screen.dart';
import '../features/manager/screens/inventory_screen.dart';
import '../features/manager/screens/users_screen.dart';
import '../features/manager/screens/assign_delivery_screen.dart';
import '../features/manager/screens/banner_management_screen.dart';
import '../features/manager/screens/banner_form_screen.dart';
import '../features/manager/screens/cashier_order_screen.dart';
import '../features/manager/screens/bulk_operations_screen.dart';
import '../features/manager/screens/product_analytics_screen.dart';
import '../features/manager/screens/delivery_revenue_screen.dart';
import '../features/manager/widgets/manager_shell.dart';
import '../features/kitchen/screens/kitchen_orders_screen.dart';
import '../features/kitchen/widgets/kitchen_shell.dart';
import '../features/delivery/widgets/delivery_shell.dart';

/// Listenable to refresh GoRouter without recreating it when auth state changes
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    // Listen to auth provider changes and notify the router to re-evaluate redirects
    ref.listen<AsyncValue<UserModel?>>(authProvider, (previous, next) {
      Logger.debug('RouterNotifier: Auth state changed', tag: 'Router');
      Logger.debug(
        '   Notifying router to re-evaluate redirects',
        tag: 'Router',
      );
      notifyListeners();
    });

    // Listen to organization context changes - reload ONLY the org role, not entire auth state
    // This prevents race conditions and double rebuilds during org switching
    ref.listen<AsyncValue<String?>>(currentOrganizationProvider, (
      previous,
      next,
    ) {
      if (previous?.value != next.value) {
        Logger.debug('RouterNotifier: Org context changed, reloading role', tag: 'Router');
        // Reload ONLY the role, not entire auth state - prevents race condition
        ref.read(authProvider.notifier).reloadOrgRole();
        notifyListeners();
      }
    });

    // Listen to screen persistence to update route once loaded
    ref.listen<AsyncValue<String?>>(screenPersistenceProvider, (
      previous,
      next,
    ) {
      if (previous?.isLoading == true && !next.isLoading) {
        Logger.debug('RouterNotifier: Persistence loaded', tag: 'Router');
        notifyListeners();
      }
    });
  }

  final Ref ref;
}

/// Provider per il router
final routerProvider = Provider<GoRouter>((ref) {
  // Keep a single GoRouter instance and refresh it on auth changes
  final notifier = RouterNotifier(ref);
  ref.onDispose(() => notifier.dispose());

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      Logger.debug('Router redirect called', tag: 'Router');
      Logger.debug(
        '   Current location: ${state.matchedLocation}',
        tag: 'Router',
      );

      final authState = ref.read(authProvider);
      if (authState.isLoading) {
        Logger.debug('   Auth still loading - skip redirect', tag: 'Router');
        return null;
      }
      Logger.debug(
        '   Auth state: ${authState.isLoading
            ? "Loading..."
            : authState.value != null
            ? "Authenticated"
            : "Not authenticated"}',
        tag: 'Router',
      );

      final orgState = ref.read(currentOrganizationProvider);
      if (orgState.isLoading) {
        Logger.debug('   Org context loading - skip redirect', tag: 'Router');
        return null;
      }

      final hasOrgContext = orgState.maybeWhen(
        data: (orgId) => orgId != null,
        orElse: () => false,
      );

      final isAuthenticated = authState.value != null;
      final isLoginRoute = state.matchedLocation == RouteNames.login;
      final isRoot = state.matchedLocation == '/';

      final onboardingRoutes = [RouteNames.connect, RouteNames.joinOrg];
      final isOnboardingRoute = onboardingRoutes.any(
        (r) => state.matchedLocation.startsWith(r),
      );

      if (!hasOrgContext && !isOnboardingRoute) {
        Logger.debug(
          '   → Redirecting to connect (missing org context)',
          tag: 'Router',
        );
        return RouteNames.connect;
      }

      if (hasOrgContext && !isAuthenticated && !isOnboardingRoute) {
        if (!isLoginRoute) {
          Logger.debug(
            '   → Redirecting to login (org set, not authenticated)',
            tag: 'Router',
          );
          return RouteNames.login;
        }
      }

      // Autenticato e su login o root -> vai alla home del suo ruolo o last screen
      if (isAuthenticated && (isLoginRoute || isRoot)) {
        final user = authState.value!;

        // Try to get last viewed screen from persistence
        final screenPersistence = ref.read(screenPersistenceProvider);

        // If persistence is still loading, wait for it (RouterNotifier will trigger re-check)
        if (screenPersistence.isLoading) {
          Logger.debug(
            '   → Screen persistence loading, waiting...',
            tag: 'Router',
          );
          return null;
        }

        final homeRoute = screenPersistence.maybeWhen(
          data: (savedScreen) {
            // Use the notifier's getInitialRoute method
            return ref
                .read(screenPersistenceProvider.notifier)
                .getInitialRoute(
                  userRole: user.ruolo.name,
                  lastScreen: savedScreen,
                );
          },
          orElse: () => _getHomeRouteForRole(user.ruolo),
        );

        Logger.debug(
          '   → Redirecting to $homeRoute (authenticated as ${user.ruolo.name}, last screen: ${screenPersistence.value})',
          tag: 'Router',
        );
        return homeRoute;
      }

      Logger.debug('   → No redirect needed', tag: 'Router');
      return null;
    },
    routes: [
      // ========== Auth Routes ==========
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.connect,
        name: 'connect',
        builder: (context, state) => const ConnectScreen(),
      ),
      GoRoute(
        path: '${RouteNames.joinOrg}/:slug',
        name: 'join-org',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return OrganizationPreviewScreen(slug: slug);
        },
      ),
      GoRoute(
        path: RouteNames.switchOrg,
        name: 'switch-org',
        builder: (context, state) => const OrganizationSwitcherScreen(),
      ),

      // ========== Customer Routes ==========
      // ========== Customer Routes ==========
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            constrainWidth: true,
            showMobileTopBar: true,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: RouteNames.menu,
            name: 'menu',
            pageBuilder: (context, state) =>
                const MaterialPage(child: MenuScreen()),
          ),
          GoRoute(
            path: RouteNames.currentOrder,
            name: 'current-order',
            pageBuilder: (context, state) =>
                const MaterialPage(child: CurrentOrderScreen()),
          ),
          GoRoute(
            path: RouteNames.cart,
            name: 'cart',
            pageBuilder: (context, state) =>
                const MaterialPage(child: CartScreenNew()),
          ), // New checkout flow routes
          GoRoute(
            path: '/cart-new',
            name: 'cart-new',
            pageBuilder: (context, state) =>
                const MaterialPage(child: CartScreenNew()),
          ),
          GoRoute(
            path: '/checkout-time-selection',
            name: 'checkout-time-selection',
            pageBuilder: (context, state) {
              final orderType = state.extra as OrderType;
              return MaterialPage(
                child: CheckoutTimeSelectionScreen(orderType: orderType),
              );
            },
          ),
          GoRoute(
            path: '/checkout-new',
            name: 'checkout-new',
            pageBuilder: (context, state) {
              final data = state.extra as Map<String, dynamic>;
              return MaterialPage(
                child: CheckoutScreenNew(
                  orderType: data['orderType'] as OrderType,
                  selectedSlot: data['selectedSlot'] as DateTime,
                  selectedAddress: data['selectedAddress'] as UserAddressModel?,
                  selectedDate: data['selectedDate'] as DateTime,
                ),
              );
            },
          ),
          GoRoute(
            path: RouteNames.customerProfile,
            name: 'profile',
            pageBuilder: (context, state) =>
                const MaterialPage(child: ProfileScreen()),
          ),
        ],
      ),

      // ========== Manager Routes ==========
      GoRoute(
        path: RouteNames.dashboard,
        name: 'dashboard',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ManagerShell(child: DashboardScreen()),
        ),
      ),
      GoRoute(
        path: RouteNames.staffManagement,
        name: 'staff-management',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: ManagerShell(child: UsersScreen())),
      ),
      GoRoute(
        path: RouteNames.managerMenu,
        name: 'manager-menu',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ManagerShell(child: ManagerMenuScreen()),
        ),
      ),
      GoRoute(
        path: RouteNames.managerOrders,
        name: 'manager-orders',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: ManagerShell(child: OrdersScreen())),
      ),
      GoRoute(
        path: RouteNames.assignDelivery,
        name: 'assign-delivery',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ManagerShell(child: AssignDeliveryScreen()),
        ),
      ),
      GoRoute(
        path: RouteNames.settings,
        name: 'settings',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ManagerShell(child: SettingsScreen()),
        ),
      ),
      GoRoute(
        path: '/manager/sizes',
        name: 'sizes-master',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ManagerShell(child: SizeVariantsScreen()),
        ),
      ),
      GoRoute(
        path: RouteNames.inventory,
        name: 'inventory',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ManagerShell(child: InventoryScreen()),
        ),
      ),
      GoRoute(
        path: '/manager/banners',
        name: 'banner-management',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ManagerShell(child: BannerManagementScreen()),
        ),
      ),
      GoRoute(
        path: '/manager/banners/new',
        name: 'banner-new',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ManagerShell(child: BannerFormScreen()),
        ),
      ),
      GoRoute(
        path: '/manager/banners/edit/:id',
        name: 'banner-edit',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) {
          final bannerId = state.pathParameters['id'];
          return NoTransitionPage(
            child: ManagerShell(child: BannerFormScreen(bannerId: bannerId)),
          );
        },
      ),
      GoRoute(
        path: RouteNames.cashierOrder,
        name: 'cashier-order',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ManagerShell(child: CashierOrderScreen()),
        ),
      ),
      GoRoute(
        path: RouteNames.bulkOperations,
        name: 'bulk-operations',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ManagerShell(child: BulkOperationsScreen()),
        ),
      ),
      GoRoute(
        path: RouteNames.productAnalytics,
        name: 'product-analytics',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ManagerShell(child: ProductAnalyticsScreen()),
        ),
      ),
      GoRoute(
        path: RouteNames.deliveryRevenue,
        name: 'delivery-revenue',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.manager],
          state: state,
        ),
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ManagerShell(child: DeliveryRevenueScreen()),
        ),
      ),
      // Legacy category-based routes removed

      // ========== Kitchen Routes ==========
      GoRoute(
        path: RouteNames.kitchenOrders,
        name: 'kitchen-orders',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.kitchen, UserRole.manager],
          state: state,
        ),
        builder: (context, state) =>
            const KitchenShell(child: KitchenOrdersScreen()),
      ),

      // ========== Delivery Routes ==========
      GoRoute(
        path: RouteNames.deliveryReady,
        name: 'delivery-orders',
        redirect: (context, state) => _redirectProtectedRoute(
          authState: ref.read(authProvider),
          allowedRoles: const [UserRole.delivery, UserRole.manager],
          state: state,
        ),
        builder: (context, state) => const DeliveryShell(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Pagina non trovata',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.matchedLocation),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.menu),
              child: const Text('Torna alla Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Determina la route home in base al ruolo
String _getHomeRouteForRole(UserRole role) {
  switch (role) {
    case UserRole.customer:
      return RouteNames.menu;
    case UserRole.manager:
      return RouteNames.dashboard;
    case UserRole.kitchen:
      return RouteNames.kitchenOrders;
    case UserRole.delivery:
      return RouteNames.deliveryReady;
  }
}

String? _redirectProtectedRoute({
  required AsyncValue<UserModel?> authState,
  required List<UserRole> allowedRoles,
  required GoRouterState state,
}) {
  if (authState.isLoading) return null;

  final user = authState.value;
  if (user == null) {
    return RouteNames.menu;
  }

  if (!allowedRoles.contains(user.ruolo)) {
    final fallback = _getHomeRouteForRole(user.ruolo);
    if (fallback == state.matchedLocation) {
      return RouteNames.menu;
    }
    return fallback;
  }

  return null;
}
