import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/screen_persistence_provider.dart';
import '../../../core/utils/welcome_popup_manager.dart';
import '../../../core/utils/constants.dart';
import '../../../core/widgets/manager_quick_switch.dart';
import '../../../core/widgets/pizzeria_logo.dart';
import '../../../core/utils/enums.dart';
import '../../../core/navigation/back_navigation_handler.dart';

/// Kitchen app shell with simple navigation
class KitchenShell extends ConsumerStatefulWidget {
  final Widget child;

  const KitchenShell({super.key, required this.child});

  @override
  ConsumerState<KitchenShell> createState() => _KitchenShellState();
}

class _KitchenShellState extends ConsumerState<KitchenShell> {
  @override
  void initState() {
    super.initState();
    // Save current shell to persistence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(screenPersistenceProvider.notifier)
          .saveCurrentScreen(RouteNames.kitchenOrders);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final user = ref.watch(authProvider).value;

    final role = user?.ruolo;
    final canAccess = role == UserRole.kitchen || role == UserRole.manager;
    if (!canAccess) {
      return const BackNavigationHandler(
        fallbackToMenu: false,
        child: _UnauthorizedKitchenView(),
      );
    }

    return BackNavigationHandler(
      fallbackToMenu: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Header bar
                  _buildHeader(context, ref, user, isDesktop),

                  // Main content
                  Expanded(child: widget.child),
                ],
              ),
              const Positioned(
                bottom: 0,
                right: 0,
                child: ManagerQuickSwitch(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    user,
    bool isDesktop,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppBreakpoints.responsive(
          context: context,
          mobile: AppSpacing.lg,
          tablet: AppSpacing.xxl,
          desktop: AppSpacing.massive,
        ),
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.orangeGradient,
        ),
        boxShadow: AppShadows.md,
      ),
      child: Row(
        children: [
          // Logo and title
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: AppRadius.radiusLG,
            ),
            padding: const EdgeInsets.all(4),
            child: const PizzeriaLogo(
              size: 40,
              showGradient: false,
              fallbackIcon: Icons.restaurant_rounded,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cucina',
                  style:
                      (isDesktop
                              ? AppTypography.titleLarge
                              : AppTypography.titleMedium)
                          .copyWith(
                            color: Colors.white,
                            fontWeight: AppTypography.black,
                          ),
                ),
                Text(
                  user?.nome ?? 'Staff',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),

          // Logout button
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            color: Colors.white,
            onPressed: () async {
              await WelcomePopupManager.reset();
              await ref.read(authProvider.notifier).signOut();
            },
            tooltip: 'Esci',
          ),
        ],
      ),
    );
  }
}

class _UnauthorizedKitchenView extends StatelessWidget {
  const _UnauthorizedKitchenView();

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
                'Accesso alla cucina non autorizzato',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: AppTypography.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Solo lo staff cucina o i manager possono visualizzare questa schermata.',
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
