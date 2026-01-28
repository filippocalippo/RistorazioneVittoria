import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../DesignSystem/design_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../core/providers/top_bar_scroll_provider.dart';
import '../../core/utils/constants.dart';
import 'app_navigation.dart';
import 'manager_quick_switch.dart';
import 'mobile_top_bar.dart';
import '../navigation/back_navigation_handler.dart';
import 'offline_banner.dart';

/// Main app shell that provides consistent navigation across screens
class AppShell extends ConsumerWidget {
  final Widget child;
  final bool showNavigation;
  final bool constrainWidth; // For customer screens to have narrower max-width
  final bool showMobileTopBar; // For mobile customer screens

  const AppShell({
    super.key,
    required this.child,
    this.showNavigation = true,
    this.constrainWidth = false,
    this.showMobileTopBar = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isMobile = AppBreakpoints.isMobile(context);
    final isUserAuthenticated = ref.watch(isAuthenticatedProvider);
    final currentPath = GoRouterState.of(context).matchedLocation;
    final hideBottomNav = currentPath == RouteNames.cart || currentPath == RouteNames.checkout ||
        currentPath == '/cart-new' || currentPath == '/checkout-time-selection' || currentPath == '/checkout-new';

    // Apply width constraint wrapper
    Widget content = constrainWidth
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400 * 1.20),
              child: child,
            ),
          )
        : child;

    // Global scroll listener for top bar glassmorphism
    content = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.axis == Axis.vertical) {
          // Calculate scroll progress (0.0 to 1.0)
          // Slower transition: 85.0 pixels to fully appear (was 50.0)
          final progress = (notification.metrics.pixels / 120.0).clamp(0.0, 1.0);
          // Use Future.microtask to avoid build phase updates if necessary,
          // but usually provider state update is fine.
          // However, updating provider during build/layout might cause issues.
          // NotificationListener is called during layout/paint usually.
          // Let's try direct update first.
          ref.read(topBarScrollProvider.notifier).state = progress;
        }
        return false;
      },
      child: content,
    );

    // If no navigation, return just the content (with constraints if needed)
    if (!showNavigation) {
      // Wrap in Scaffold to provide background when constrained
      if (constrainWidth) {
        return BackNavigationHandler(
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.white,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: Colors.white,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            child: Container(
              color: isMobile ? AppColors.surface : AppColors.background,
              child: Scaffold(
                backgroundColor: isMobile
                    ? AppColors.surface
                    : AppColors.background,
                body: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const OfflineBanner(),
                      Expanded(child: content),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return BackNavigationHandler(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const OfflineBanner(),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    // For non-authenticated users, show mobile top bar and bottom nav (cart + menu)
    if (!isUserAuthenticated) {
      return BackNavigationHandler(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Container(
            color: isMobile ? AppColors.surface : AppColors.background,
            child: Scaffold(
              backgroundColor: isMobile
                  ? AppColors.surface
                  : AppColors.background,
              body: SafeArea(
                top: false, // MobileTopBar handles its own SafeArea
                bottom:
                    false, // We'll handle bottom padding manually for floating nav
                child: Column(
                  children: [
                    const OfflineBanner(),
                    Expanded(
                      child: Stack(
                        children: [
                          Stack(
                            children: [
                              // Main content with optional width constraint
                              // Wrapped in Padding to account for system nav buttons
                              Positioned.fill(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(context).padding.bottom,
                                  ),
                                  child: content,
                                ),
                              ),

                              // Mobile top bar for customer screens
                              if (isMobile && showMobileTopBar)
                                const Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: MobileTopBar(),
                                ),
                            ],
                          ),

                          // Floating bottom navigation for mobile - show cart and menu to all users, but hide on cart/checkout
                          if (isMobile && !hideBottomNav)
                            const Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: MobileBottomNav(),
                            ),
                        ],
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

    return BackNavigationHandler(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Container(
          // Match the top bar color for the status bar area
          color: isMobile ? AppColors.surface : AppColors.background,
          child: Scaffold(
            backgroundColor: isMobile ? AppColors.surface : AppColors.background,
            body: SafeArea(
              top: false, // MobileTopBar handles its own SafeArea
              bottom:
                  false, // We'll handle bottom padding manually for floating nav
              child: Column(
                children: [
                  const OfflineBanner(),
                  Expanded(
                    child: Stack(
                      children: [
                        Stack(
                          children: [
                            // Main content
                            Positioned.fill(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).padding.bottom,
                                ),
                                child: isDesktop && isUserAuthenticated
                                    ? Column(
                                        children: [
                                          const DesktopNavBar(),
                                          Expanded(child: content),
                                        ],
                                      )
                                    : content,
                              ),
                            ),

                            // Mobile top bar for customer screens
                            if (isMobile && showMobileTopBar)
                              const Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: MobileTopBar(),
                              ),
                          ],
                        ),

                        // Floating bottom navigation for mobile (positioned on top of content)
                        // This already has SafeArea inside it
                        // Show for all users (cart + menu), but hide on cart/checkout
                        if (isMobile && !hideBottomNav)
                          const Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: MobileBottomNav(),
                          ),

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
        ),
      ),
    );
  }
}
