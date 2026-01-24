import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../utils/constants.dart';
import '../../providers/menu_navigation_provider.dart';

/// Centralized handler to make the system back button behave consistently.
/// Priority:
/// 1) Close the current navigator entry (bottom sheet, dialog, pushed page)
/// 2) Collapse customer menu product view back to categories
/// 3) Pop GoRouter history
/// 4) Fallback to home menu instead of exiting on deep links
class BackNavigationHandler extends ConsumerWidget {
  final Widget child;
  final bool fallbackToMenu;

  const BackNavigationHandler({
    super.key,
    required this.child,
    this.fallbackToMenu = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter.of(context);

    return BackButtonListener(
      onBackButtonPressed: () async {
        final navigator = Navigator.of(context);

        // Pop any pending route (dialogs, sheets, nested pages) first
        if (await navigator.maybePop()) {
          return true;
        }

        // Collapse menu product view back to the category grid
        final isMenuProductView = ref.read(isMenuProductViewProvider);
        final isMenuBackInProgress =
            ref.read(menuBackNavigationInProgressProvider);
        if (isMenuProductView && !isMenuBackInProgress) {
          ref.read(menuBackNavigationInProgressProvider.notifier).state = true;
          ref.read(menuResetTriggerProvider.notifier).state++;
          return true;
        }

        // Pop GoRouter history (covers ShellRoute stacks)
        if (router.canPop()) {
          router.pop();
          return true;
        }

        // If we landed deep via link and can't pop, return to home instead of exiting
        if (fallbackToMenu) {
          final currentPath = router.routerDelegate.currentConfiguration.uri.path;
          if (currentPath != RouteNames.menu) {
            router.go(RouteNames.menu);
            return true;
          }
        }

        // Allow system default (usually exit app)
        return false;
      },
      child: child,
    );
  }
}
