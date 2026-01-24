import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../DesignSystem/design_tokens.dart';
import '../utils/constants.dart';
import '../../providers/auth_provider.dart';
import '../utils/enums.dart';

/// Floating bottom-right quick switch for managers
class ManagerQuickSwitch extends ConsumerWidget {
  const ManagerQuickSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    if (user == null || user.ruolo != UserRole.manager) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 75.0, left: AppSpacing.sm),
        child: _MenuButton(),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.radiusLG,
          boxShadow: AppShadows.md,
          border: Border.all(color: AppColors.border),
        ),
        child: PopupMenuButton<_Dest>(
          tooltip: 'Quick switch',
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLG),
          itemBuilder: (context) => [
            _item(_Dest('Customer Menu', Icons.local_pizza, RouteNames.menu)),
            _item(
              _Dest(
                'Manager Dashboard',
                Icons.dashboard_rounded,
                RouteNames.dashboard,
              ),
            ),
            _item(
              _Dest(
                'Delivery Dashboard',
                Icons.delivery_dining_rounded,
                RouteNames.deliveryReady,
              ),
            ),
            _item(
              _Dest(
                'Kitchen Screen',
                Icons.kitchen_rounded,
                RouteNames.kitchenOrders,
              ),
            ),
          ],
          onSelected: (dest) => context.go(dest.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.black87),
                SizedBox(width: 6),
                Text('Switch view'),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_Dest> _item(_Dest dest) {
    return PopupMenuItem<_Dest>(
      value: dest,
      child: Row(
        children: [
          Icon(dest.icon, size: 18),
          const SizedBox(width: 8),
          Text(dest.label),
        ],
      ),
    );
  }
}

class _Dest {
  final String label;
  final IconData icon;
  final String route;
  _Dest(this.label, this.icon, this.route);
}
