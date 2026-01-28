import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  GoRouter? _router;
  bool _initialized = false;

  Future<void> init(GoRouter router) async {
    if (_initialized) return;
    _initialized = true;
    _router = router;

    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleUri(initialLink);
      }
    } catch (e) {
      Logger.warning('Deep link initial read failed: $e', tag: 'DeepLink');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (err) {
        Logger.error('Deep link stream error: $err', tag: 'DeepLink');
      },
    );
  }

  void _handleUri(Uri uri) {
    final router = _router;
    if (router == null) return;

    final segments = uri.pathSegments;
    if (segments.isNotEmpty &&
        segments.first == 'join' &&
        segments.length >= 2) {
      final slug = segments[1];
      router.go('${RouteNames.joinOrg}/$slug');
      return;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
