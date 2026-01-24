import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to track scroll progress for the top bar glassmorphism effect
/// 0.0 means not scrolled (transparent), 1.0 means fully scrolled (glassmorphic)
final topBarScrollProvider = StateProvider<double>((ref) => 0.0);
