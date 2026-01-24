import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/utils/constants.dart';
import 'delivery_shell.dart';

/// Bottom navigation bar for delivery screens
class DeliveryBottomNav extends ConsumerWidget {
  final DeliveryView currentView;

  const DeliveryBottomNav({
    super.key,
    required this.currentView,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: AppShadows.xl,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.list_alt_rounded,
                label: 'Coda',
                isActive: currentView == DeliveryView.queue,
                onTap: () {
                  ref.read(deliveryViewProvider.notifier).state = DeliveryView.queue;
                },
              ),
              _NavItem(
                icon: Icons.map_outlined,
                label: 'Mappa',
                isActive: currentView == DeliveryView.map,
                onTap: () {
                  ref.read(deliveryViewProvider.notifier).state = DeliveryView.map;
                },
                showBadge: currentView != DeliveryView.map,
              ),
              _NavItem(
                icon: Icons.storefront_outlined,
                label: 'Cliente',
                isActive: false,
                onTap: () {
                  context.go(RouteNames.menu);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool showBadge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: isActive ? AppColors.primary : AppColors.textTertiary,
                  ),
                  if (showBadge)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.captionSmall.copyWith(
                  color: isActive ? AppColors.primary : AppColors.textTertiary,
                  fontWeight: isActive ? AppTypography.bold : AppTypography.medium,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

