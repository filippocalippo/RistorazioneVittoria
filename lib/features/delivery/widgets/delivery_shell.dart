import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/order_model.dart';
import '../../../core/utils/enums.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/delivery_orders_provider.dart';
import '../../../providers/screen_persistence_provider.dart';
import '../../../core/utils/constants.dart';
import '../screens/delivery_dashboard_screen.dart';
import '../screens/delivery_global_map_screen.dart';
import '../screens/delivery_active_screen.dart';
import '../../../core/navigation/back_navigation_handler.dart';
import '../../../core/widgets/manager_quick_switch.dart';
import '../../../core/widgets/offline_banner.dart';

/// Delivery view modes
enum DeliveryView { queue, map, active }

/// State provider for current delivery view
final deliveryViewProvider = StateProvider<DeliveryView>(
  (ref) => DeliveryView.queue,
);

/// State provider for active order being delivered
final activeDeliveryOrderProvider = StateProvider<OrderModel?>((ref) => null);

/// Delivery app shell that manages three main views: queue, map, and active delivery
class DeliveryShell extends ConsumerStatefulWidget {
  const DeliveryShell({super.key});

  @override
  ConsumerState<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends ConsumerState<DeliveryShell> {
  bool _hasCheckedActiveDelivery = false;

  @override
  void initState() {
    super.initState();
    // Save current shell to persistence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(screenPersistenceProvider.notifier)
          .saveCurrentScreen(RouteNames.deliveryReady);
    });
  }

  void _checkForActiveDelivery(List<OrderModel> orders) {
    if (_hasCheckedActiveDelivery) return;
    _hasCheckedActiveDelivery = true;

    // Find any order with "delivering" status
    final activeOrder = orders.cast<OrderModel?>().firstWhere(
      (order) => order?.stato == OrderStatus.delivering,
      orElse: () => null,
    );

    if (activeOrder != null) {
      // Navigate to active delivery screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeDeliveryOrderProvider.notifier).state = activeOrder;
        ref.read(deliveryViewProvider.notifier).state = DeliveryView.active;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final role = user?.ruolo;
    final canAccess = role == UserRole.delivery || role == UserRole.manager;

    if (!canAccess) {
      return const BackNavigationHandler(
        fallbackToMenu: false,
        child: _UnauthorizedDeliveryView(),
      );
    }

    // Watch orders and check for active delivery
    final ordersAsync = ref.watch(deliveryOrdersRealtimeProvider);
    ordersAsync.whenData((orders) {
      _checkForActiveDelivery(orders);
    });

    final currentView = ref.watch(deliveryViewProvider);
    final activeOrder = ref.watch(activeDeliveryOrderProvider);

    // Determine which screen to show based on current view
    Widget currentScreen;
    switch (currentView) {
      case DeliveryView.queue:
        currentScreen = const DeliveryDashboardScreen();
        break;
      case DeliveryView.map:
        currentScreen = const DeliveryGlobalMapScreen();
        break;
      case DeliveryView.active:
        if (activeOrder != null) {
          currentScreen = DeliveryActiveScreen(order: activeOrder);
        } else {
          // Fallback to queue if no active order
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(deliveryViewProvider.notifier).state = DeliveryView.queue;
          });
          currentScreen = const DeliveryDashboardScreen();
        }
        break;
    }

    return BackNavigationHandler(
      fallbackToMenu: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: Stack(
                  children: [
                    currentScreen,
                    if (currentView != DeliveryView.active)
                      const Positioned(
                        bottom: 0,
                        left: 0,
                        child: ManagerQuickSwitch(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unauthorized access view for non-delivery users
class _UnauthorizedDeliveryView extends StatelessWidget {
  const _UnauthorizedDeliveryView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: AppSpacing.paddingXXL,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Accesso alle consegne non autorizzato',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: AppTypography.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Solo i driver o i manager possono visualizzare questa schermata.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
