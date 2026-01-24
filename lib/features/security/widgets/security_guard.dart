import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/security_provider.dart';
import '../screens/lock_screen.dart';
import '../screens/security_setup_screen.dart';
import '../screens/security_recovery_screen.dart';

class SecurityGuard extends ConsumerStatefulWidget {
  final Widget child;

  const SecurityGuard({super.key, required this.child});

  @override
  ConsumerState<SecurityGuard> createState() => _SecurityGuardState();
}

class _SecurityGuardState extends ConsumerState<SecurityGuard> {
  bool _showRecovery = false;

  @override
  void initState() {
    super.initState();
    // Lock EVERY time this widget is mounted/entered.
    // This ensures navigating to dashboard always requires password.
    // We use addPostFrameCallback to avoid modifying provider during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(securityStateProvider.notifier).lock();
      }
    });
  }

  @override
  void dispose() {
    // Also lock on dispose as a safety net for any edge cases
    // Lock BEFORE super.dispose() to ensure ref is still valid
    ref.read(securityStateProvider.notifier).lock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final securityState = ref.watch(securityStateProvider);

    // If still loading security status, show nothing or loading
    if (securityState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 1. Setup Required (First time or after reset)
    if (securityState.isSetupRequired) {
      return SecuritySetupScreen(
        onCompleted: () {
          // Setup calls setup() in provider which updates state automatically
          // Just need to ensure UI reacts (it will via Riverpod)
        },
      );
    }

    // 2. Locked State
    if (securityState.isLocked) {
      if (_showRecovery) {
        return SecurityRecoveryScreen(
          onCancel: () => setState(() => _showRecovery = false),
        );
      }
      
      return LockScreen(
        onForgot: () => setState(() => _showRecovery = true),
      );
    }

    // 3. Unlocked - Show Content
    return widget.child;
  }
}
