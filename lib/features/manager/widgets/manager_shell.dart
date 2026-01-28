import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/enums.dart';
import '../../../core/utils/welcome_popup_manager.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/screen_persistence_provider.dart';
import '../../../core/widgets/manager_quick_switch.dart';
import '../../../core/widgets/pizzeria_logo.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../../../core/navigation/back_navigation_handler.dart';
import '../../../core/widgets/offline_banner.dart';

/// Manager app shell with sidebar navigation
class ManagerShell extends ConsumerStatefulWidget {
  final Widget child;

  const ManagerShell({super.key, required this.child});

  @override
  ConsumerState<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends ConsumerState<ManagerShell> {
  String? _lastPersistedPath;

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final user = ref.watch(authProvider).value;
    final currentPath = GoRouterState.of(context).matchedLocation;

    // Persist the current route when it changes
    if (_lastPersistedPath != currentPath) {
      _lastPersistedPath = currentPath;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(screenPersistenceProvider.notifier)
            .saveCurrentScreen(currentPath);
      });
    }

    if (user?.ruolo != UserRole.manager) {
      return const BackNavigationHandler(
        fallbackToMenu: false,
        child: _UnauthorizedManagerView(),
      );
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
                    Row(
                      children: [
                        // Sidebar (desktop only)
                        if (isDesktop) _buildSidebar(context, ref, user),

                        // Main content
                        Expanded(child: widget.child),
                      ],
                    ),
                    if (currentPath != RouteNames.cashierOrder)
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
        // Bottom navigation (mobile/tablet)
        bottomNavigationBar: !isDesktop ? _buildBottomNav(context) : null,
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, WidgetRef ref, user) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.md,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.orangeGradient,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    final settings = ref.watch(pizzeriaSettingsProvider).value;
                    return Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: AppRadius.radiusLG,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const PizzeriaLogo(
                            size: 40,
                            showGradient: false,
                            fallbackIcon: Icons.local_pizza,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            settings?.pizzeria.nome ?? 'Rotante',
                            style: AppTypography.titleLarge.copyWith(
                              color: Colors.white,
                              fontWeight: AppTypography.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Manager Dashboard',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              children: [
                _NavTreeGroup(
                  label: 'Dashboard',
                  icon: Icons.dashboard_rounded,
                  route: RouteNames.dashboard,
                  isActive: currentPath == RouteNames.dashboard,
                  onTap: () => context.go(RouteNames.dashboard),
                  initiallyExpanded:
                      currentPath == '/manager/banners' ||
                      currentPath == RouteNames.staffManagement,
                  children: [
                    _SidebarItem(
                      icon: Icons.campaign_rounded,
                      label: 'Banner Pubblicità',
                      isActive: currentPath == '/manager/banners',
                      onTap: () => context.go('/manager/banners'),
                    ),
                    _SidebarItem(
                      icon: Icons.groups_rounded,
                      label: 'Staff',
                      isActive: currentPath == RouteNames.staffManagement,
                      onTap: () => context.go(RouteNames.staffManagement),
                    ),
                  ],
                ),
                _NavTreeGroup(
                  label: 'Menu',
                  icon: Icons.restaurant_menu_rounded,
                  route: RouteNames.managerMenu,
                  isActive: currentPath == RouteNames.managerMenu,
                  onTap: () => context.go(RouteNames.managerMenu),
                  initiallyExpanded: currentPath == RouteNames.inventory,
                  children: [
                    _SidebarItem(
                      icon: Icons.inventory_2_rounded,
                      label: 'Ingredienti e Inventario',
                      isActive: currentPath == RouteNames.inventory,
                      onTap: () => context.go(RouteNames.inventory),
                    ),
                  ],
                ),
                _NavTreeGroup(
                  label: 'Ordini',
                  icon: Icons.receipt_long_rounded,
                  route: RouteNames.managerOrders,
                  isActive: currentPath == RouteNames.managerOrders,
                  onTap: () => context.go(RouteNames.managerOrders),
                  initiallyExpanded: currentPath == RouteNames.assignDelivery,
                  children: [
                    _SidebarItem(
                      icon: Icons.assignment_rounded,
                      label: 'Assegna Consegne',
                      isActive: currentPath == RouteNames.assignDelivery,
                      onTap: () => context.go(RouteNames.assignDelivery),
                    ),
                  ],
                ),
                _SidebarItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'Cassa Ordini',
                  isActive: currentPath == RouteNames.cashierOrder,
                  onTap: () => context.go(RouteNames.cashierOrder),
                ),
                const Divider(height: AppSpacing.xxl),
                _SidebarItem(
                  icon: Icons.settings_rounded,
                  label: 'Impostazioni',
                  isActive: currentPath == RouteNames.settings,
                  onTap: () => context.go(RouteNames.settings),
                ),
              ],
            ),
          ),

          // User menu
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user?.nome?.substring(0, 1).toUpperCase() ?? 'M',
                    style: AppTypography.labelMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.nome ?? 'Manager',
                        style: AppTypography.labelMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.email ?? '',
                        style: AppTypography.captionSmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  onPressed: () async {
                    await WelcomePopupManager.reset();
                    await ref.read(authProvider.notifier).signOut();
                  },
                  tooltip: 'Esci',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.xl,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.md),
          topRight: Radius.circular(AppRadius.md),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                isActive: currentPath == RouteNames.dashboard,
                onTap: () => context.go(RouteNames.dashboard),
              ),
              _BottomNavItem(
                icon: Icons.point_of_sale_rounded,
                label: 'Cassa',
                isActive: currentPath == RouteNames.cashierOrder,
                onTap: () => context.go(RouteNames.cashierOrder),
              ),
              _BottomNavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Ordini',
                isActive: currentPath == RouteNames.managerOrders,
                onTap: () => context.go(RouteNames.managerOrders),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnauthorizedManagerView extends StatelessWidget {
  const _UnauthorizedManagerView();

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
                'Accesso non autorizzato',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Questa sezione è riservata ai manager della pizzeria.',
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

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: AppRadius.radiusLG,
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : _isHovered
                    ? AppColors.surfaceLight
                    : Colors.transparent,
                borderRadius: AppRadius.radiusLG,
                border: widget.isActive
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 22,
                    color: widget.isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: AppTypography.labelMedium.copyWith(
                        color: widget.isActive
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: widget.isActive
                            ? AppTypography.bold
                            : AppTypography.medium,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusLG,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: isActive ? AppColors.primary : AppColors.textTertiary,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTypography.captionSmall.copyWith(
                    fontSize: 10,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    fontWeight: isActive
                        ? AppTypography.bold
                        : AppTypography.medium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTreeGroup extends StatefulWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;
  final VoidCallback onTap;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _NavTreeGroup({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    required this.onTap,
    this.children = const [],
    this.initiallyExpanded = false,
  });

  @override
  State<_NavTreeGroup> createState() => _NavTreeGroupState();
}

class _NavTreeGroupState extends State<_NavTreeGroup> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(_NavTreeGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded && !oldWidget.initiallyExpanded) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _SidebarItem(
                icon: widget.icon,
                label: widget.label,
                isActive: widget.isActive,
                onTap: widget.onTap,
              ),
            ),
            if (widget.children.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: IconButton(
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ),
          ],
        ),
        if (_isExpanded)
          ...widget.children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xl),
              child: child,
            ),
          ),
      ],
    );
  }
}
