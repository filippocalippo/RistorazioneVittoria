import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../../../core/widgets/pizzeria_logo.dart';
import '../../../core/utils/logger.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Show the bottom sheet immediately when this screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      LoginBottomSheet.show(context).then((_) {
        // When bottom sheet is closed, navigate back if still on login route
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    });

    // Return a minimal scaffold while bottom sheet loads
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class LoginBottomSheet extends ConsumerStatefulWidget {
  const LoginBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      useSafeArea: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const LoginBottomSheet(),
    );
  }

  @override
  ConsumerState<LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends ConsumerState<LoginBottomSheet> {
  bool _isLoading = false;

  @override
  void dispose() {
    super.dispose();
  }


  Future<void> _handleGoogleSignIn() async {
    Logger.info('=== GOOGLE SIGN-IN FLOW START ===', tag: 'LoginScreen');
    setState(() => _isLoading = true);

    try {
      Logger.info('Calling signInWithGoogle...', tag: 'LoginScreen');
      await ref.read(authProvider.notifier).signInWithGoogle();

      Logger.info(
        'signInWithGoogle completed successfully',
        tag: 'LoginScreen',
      );

      if (!mounted) {
        Logger.warning(
          'Widget not mounted after Google sign-in',
          tag: 'LoginScreen',
        );
        return;
      }

      Logger.info(
        'Google sign-in successful, closing bottom sheet and navigating',
        tag: 'LoginScreen',
      );
      Logger.info('=== GOOGLE SIGN-IN FLOW END ===', tag: 'LoginScreen');

      setState(() => _isLoading = false);
      
      // Close the bottom sheet after successful login
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      Logger.error('Google sign-in failed: $e', tag: 'LoginScreen', error: e);
      if (!mounted) return;
      _showError('Errore durante l\'accesso con Google: $e');
      setState(() => _isLoading = false);
    }
  }


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        40 + bottomPadding + keyboardHeight,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 40),
          
          // Logo
          const PizzeriaLogo(size: 72, showGradient: true),
          const SizedBox(height: 24),

          // Title
          Consumer(
            builder: (context, ref, child) {
              final pizzeria = ref
                  .watch(pizzeriaSettingsProvider)
                  .value
                  ?.pizzeria;
              return Text(
                pizzeria?.nome ?? 'Rotante',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'Accedi per continuare',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 48),

          // Google Sign-In Button
          FilledButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            icon: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Image.asset(
                    'assets/icons/google_logo.png',
                    height: 20,
                    width: 20,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.login, size: 20);
                    },
                  ),
            label: const Text(
              'Accedi con Google',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
