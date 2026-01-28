import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../DesignSystem/app_colors.dart';
import '../../../DesignSystem/app_spacing.dart';
import '../../../DesignSystem/app_radius.dart';
import '../../../core/utils/constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_join_provider.dart';

class OrganizationPreviewScreen extends ConsumerStatefulWidget {
  final String slug;

  const OrganizationPreviewScreen({super.key, required this.slug});

  @override
  ConsumerState<OrganizationPreviewScreen> createState() =>
      _OrganizationPreviewScreenState();
}

class _OrganizationPreviewScreenState
    extends ConsumerState<OrganizationPreviewScreen> {
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    Future(() => _loadPreview());
  }

  @override
  void didUpdateWidget(covariant OrganizationPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      Future(() => _loadPreview());
    }
  }

  Future<void> _loadPreview() async {
    await ref.read(organizationJoinProvider.notifier).lookupBySlug(widget.slug);
  }

  Future<void> _joinOrganization(OrganizationPreview preview) async {
    setState(() => _isJoining = true);
    try {
      await ref
          .read(organizationJoinProvider.notifier)
          .joinOrganization(preview.id);
      if (!mounted) return;
      context.go(RouteNames.menu);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante la join: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Future<void> _handleJoin(OrganizationPreview preview) async {
    final authState = ref.read(authProvider);
    final isAuthenticated = authState.value != null;

    if (!isAuthenticated) {
      try {
        await ref.read(authProvider.notifier).signInWithGoogle();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accesso annullato o fallito: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    await _joinOrganization(preview);
  }

  @override
  Widget build(BuildContext context) {
    final previewState = ref.watch(organizationJoinProvider);
    final preview = previewState.value;
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.value != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Anteprima Ristorante'),
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
        child: previewState.when(
          data: (_) {
            if (preview == null) {
              return _buildErrorState(
                'Ristorante non disponibile',
                'Il ristorante richiesto non esiste o non e attivo.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // Hero card with gradient
                _buildHeroCard(preview),
                const SizedBox(height: AppSpacing.xl),

                // Info cards
                _buildInfoCards(preview),
                const SizedBox(height: AppSpacing.xxl),

                // Join button with gradient
                _buildJoinButton(isAuthenticated),
              ],
            );
          },
          error: (error, _) => _buildErrorState(
            'Errore di connessione',
            'Impossibile caricare il ristorante. Riprova.',
          ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 100),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(OrganizationPreview preview) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.primaryGradient,
        ),
        borderRadius: BorderRadius.circular(AppRadius.massive),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo with shadow
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: preview.logoUrl != null
                  ? Image.network(
                      preview.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.storefront,
                          size: 45,
                          color: Colors.white,
                        );
                      },
                    )
                  : const Icon(
                      Icons.storefront,
                      size: 45,
                      color: Colors.white,
                    ),
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

          const SizedBox(height: AppSpacing.xl),

          // Name
          Text(
            preview.name,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Address
          Text(
            _formatAddress(preview),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards(OrganizationPreview preview) {
    return Column(
      children: [
        // Address card
        _buildInfoTile(
          icon: Icons.location_on_outlined,
          title: 'Indirizzo',
          subtitle: _formatAddress(preview),
        ),
        const SizedBox(height: AppSpacing.md),

        // Info card
        _buildInfoTile(
          icon: Icons.info_outline,
          title: 'Info',
          subtitle: 'Ristorante disponibile per ordinazioni',
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryDark,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton(bool isAuthenticated) {
    return AnimatedScale(
      scale: _isJoining ? 0.95 : 1.0,
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
              color: AppColors.primary.withValues(alpha: _isJoining ? 0.2 : 0.4),
              blurRadius: _isJoining ? 8 : 16,
              offset: Offset(0, _isJoining ? 4 : 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isJoining ? null : () => _handleJoin(ref.read(organizationJoinProvider).value!),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Center(
              child: _isJoining
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isAuthenticated) ...[
                          const Icon(
                            Icons.login_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Text(
                          isAuthenticated ? 'Unisciti' : 'Crea Account e Unisciti',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 80),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.massive),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.primaryGradient,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: FilledButton(
            onPressed: _loadPreview,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            child: Text(
              'Riprova',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatAddress(OrganizationPreview preview) {
    final parts = [
      if (preview.address != null && preview.address!.isNotEmpty)
        preview.address!,
      if (preview.city != null && preview.city!.isNotEmpty) preview.city!,
    ];
    return parts.isEmpty ? 'Indirizzo non disponibile' : parts.join(', ');
  }
}
