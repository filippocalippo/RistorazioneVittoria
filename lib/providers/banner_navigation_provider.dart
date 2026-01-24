import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'banner_navigation_provider.g.dart';

/// Provider for handling navigation from banner actions
/// Used to communicate category selection from banners to MenuScreen
@riverpod
class BannerNavigation extends _$BannerNavigation {
  @override
  String? build() => null;

  /// Set category ID to navigate to
  void setCategoryId(String? categoryId) {
    state = categoryId;
  }

  /// Clear the navigation state after handling
  void clear() {
    state = null;
  }
}
