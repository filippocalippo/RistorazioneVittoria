import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rotante/DesignSystem/design_tokens.dart';
import '../providers/security_provider.dart';

class SecuritySetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onCompleted;

  const SecuritySetupScreen({super.key, required this.onCompleted});

  @override
  ConsumerState<SecuritySetupScreen> createState() =>
      _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends ConsumerState<SecuritySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  
  bool _hasDownloaded = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _generateSecurity() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Logic moved to provider - UI just triggers it
    try {
      await ref
          .read(securityStateProvider.notifier)
          .setup(_passwordController.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore setup: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _downloadCodes() async {
    final codes = ref.read(securityStateProvider).temporaryCodes;
    if (codes == null) return;
    
    await ref.read(securityStateProvider.notifier).downloadCodes(codes);
    if (mounted) {
      setState(() => _hasDownloaded = true);
    }
  }

  void _finish() {
    if (!_hasDownloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Devi scaricare i codici prima di procedere'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    // Explicitly tell provider we are done
    ref.read(securityStateProvider.notifier).completeSetup();
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(securityStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Setup Sicurezza', style: AppTypography.titleMedium),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: state.setupStep == 0 
              ? _buildPasswordStep(state.isLoading) 
              : _buildRecoveryStep(state.temporaryCodes ?? []),
        ),
      ),
    );
  }

  Widget _buildPasswordStep(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.shield_outlined, size: 64, color: AppColors.primary),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Proteggi la tua Dashboard',
            style: AppTypography.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Imposta una password numerica o alfanumerica per accedere.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(borderRadius: AppRadius.radiusLG),
              prefixIcon: const Icon(Icons.lock),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Minimo 6 caratteri';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Confirm Field
          TextFormField(
            controller: _confirmController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Conferma Password',
              border: OutlineInputBorder(borderRadius: AppRadius.radiusLG),
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Le password non coincidono';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xxl),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : _generateSecurity,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusLG,
                ),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Continua',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryStep(List<String> codes) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.vpn_key_outlined, size: 64, color: AppColors.success),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Codici di Recupero',
          style: AppTypography.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Questi codici sono l\'unico modo per recuperare l\'accesso se dimentichi la password. Salvali in un posto sicuro!',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),

        // Codes Grid
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.radiusLG,
            border: Border.all(color: AppColors.border),
          ),
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.center,
            children: codes.map((code) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppRadius.radiusSM,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  code,
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _downloadCodes,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Scarica/Condividi Codici'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusLG,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Checkbox confirmation visual cue
        if (_hasDownloaded)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Codici salvati',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _hasDownloaded ? _finish : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.textTertiary,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusLG,
              ),
            ),
            child: const Text(
              'Ho salvato i codici, completa setup',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
