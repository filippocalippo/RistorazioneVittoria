import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../DesignSystem/app_colors.dart';
import '../../../DesignSystem/app_spacing.dart';
import '../../../DesignSystem/app_radius.dart';
import '../../../DesignSystem/app_shadows.dart';
import '../../../core/utils/constants.dart';
import '../../../providers/organization_join_provider.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final TextEditingController _slugController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _slugController.dispose();
    super.dispose();
  }

  String? _extractSlug(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme.isNotEmpty) {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty && segments.first == 'join' && segments.length >= 2) {
        return segments[1];
      }
    }

    final match = RegExp(r'join/([a-zA-Z0-9-]+)').firstMatch(trimmed);
    if (match != null) return match.group(1);

    final slugMatch = RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(trimmed);
    if (slugMatch) return trimmed;

    return null;
  }

  Future<void> _lookupOrganization(String input) async {
    final slug = _extractSlug(input);
    if (slug == null) {
      setState(() {
        _errorMessage = 'Inserisci uno slug valido o un link corretto.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final preview = await ref
          .read(organizationJoinProvider.notifier)
          .lookupBySlug(slug);
      if (!mounted) return;

      if (preview == null) {
        setState(() {
          _errorMessage = 'Ristorante non trovato o non attivo.';
          _isLoading = false;
        });
        return;
      }

      setState(() => _isLoading = false);
      context.go('${RouteNames.joinOrg}/$slug');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Errore di connessione. Riprova.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _JoinQrScannerScreen()),
    );
    if (!mounted) return;
    if (result == null || result.trim().isEmpty) return;
    _slugController.text = result;
    await _lookupOrganization(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Connetti Ristorante'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),

            // Hero section with gradient
            _buildHeroSection(),
            const SizedBox(height: AppSpacing.xxl),

            // Divider
            Row(
              children: [
                Expanded(child: Container(height: 1, color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    'OPPURE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(child: Container(height: 1, color: AppColors.border)),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Input section
            _buildInputSection(),
            const SizedBox(height: AppSpacing.xl),

            // Continue button with gradient
            _buildContinueButton(),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        // Gradient illustration container
        Container(
          padding: const EdgeInsets.all(AppSpacing.massive),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.beigeGradient,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.storefront_rounded,
            size: 64,
            color: AppColors.primaryDark,
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
        const SizedBox(height: AppSpacing.xl),

        // Title
        Text(
          'Collega il tuo ristorante',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Scansiona il QR code o inserisci il codice del ristorante',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),

        // QR Scan Card
        _buildQrCard(),
      ],
    );
  }

  Widget _buildQrCard() {
    return AnimatedScale(
      scale: _isLoading ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _openScanner,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm,
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scansiona QR Code',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Usa la fotocamera',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Codice ristorante',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _slugController,
          textInputAction: TextInputAction.go,
          enabled: !_isLoading,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'es. pizzeria-roma',
            hintStyle: GoogleFonts.inter(
              color: AppColors.textTertiary,
            ),
            filled: true,
            fillColor: AppColors.surface,
            errorText: _errorMessage,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
          ),
          onSubmitted: _isLoading ? null : _lookupOrganization,
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return AnimatedScale(
      scale: _isLoading ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.primaryGradient,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: _isLoading ? 0.2 : 0.4),
              blurRadius: _isLoading ? 8 : 16,
              offset: Offset(0, _isLoading ? 4 : 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading
                ? null
                : () => _lookupOrganization(_slugController.text),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Continua',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinQrScannerScreen extends StatefulWidget {
  const _JoinQrScannerScreen();

  @override
  State<_JoinQrScannerScreen> createState() => _JoinQrScannerScreenState();
}

class _JoinQrScannerScreenState extends State<_JoinQrScannerScreen> {
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scansiona QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_hasScanned) return;
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue;
            if (value != null && value.isNotEmpty) {
              _hasScanned = true;
              Navigator.pop(context, value);
              break;
            }
          }
        },
      ),
    );
  }
}
