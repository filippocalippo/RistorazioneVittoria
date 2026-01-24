import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to trigger menu screen reset to category grid
/// When this value changes, the menu screen should reset to category selection
final menuResetTriggerProvider = StateProvider<int>((ref) => 0);

/// Provider to track if the menu screen is showing the product list (true) or category grid (false)
final isMenuProductViewProvider = StateProvider<bool>((ref) => false);

/// Provider to avoid handling the same back press twice while animations run
final menuBackNavigationInProgressProvider = StateProvider<bool>((ref) => false);
