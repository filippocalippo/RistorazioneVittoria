import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for global search query, used by MobileTopBar and MenuScreen
final globalSearchQueryProvider = StateProvider<String>((ref) => '');
