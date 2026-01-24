import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../DesignSystem/design_tokens.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../widgets/settings_form.dart';

enum SettingsSection {
  general,
  orders,
  delivery,
  branding,
  kitchen,
  business,
  cities,
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsSection? _selectedSection;

  @override
  Widget build(BuildContext context) {
    final pizzeriaState = ref.watch(pizzeriaSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: pizzeriaState.when(
        data: (settings) {
          if (settings == null) return _buildNoDataState(context);

          if (_selectedSection == null) {
            return _buildSettingsGrid(context, settings);
          } else {
            return SettingsForm(
              settings: settings,
              initialSection: _selectedSection!,
              onBack: () => setState(() => _selectedSection = null),
            );
          }
        },
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(context),
      ),
    );
  }

  Widget _buildSettingsGrid(BuildContext context, dynamic settings) {
    final padding = AppBreakpoints.responsive(
      context: context,
      mobile: AppSpacing.lg,
      tablet: AppSpacing.xl,
      desktop: AppSpacing.xxxl,
    );

    return Column(
      children: [
        _buildHeader(context, settings),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = _resolveColumns(width);
                final spacing = AppSpacing.xl;
                final itemWidth = columns == 1
                    ? width
                    : (width - (spacing * (columns - 1))) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    _buildSettingCard(
                      width: itemWidth,
                      icon: Icons.store_rounded,
                      iconColor: AppColors.primary,
                      title: 'Informazioni Generali',
                      description: 'Dati principali e contatti della pizzeria',
                      onTap: () => setState(
                        () => _selectedSection = SettingsSection.general,
                      ),
                    ),
                    _buildSettingCard(
                      width: itemWidth,
                      icon: Icons.receipt_long_rounded,
                      iconColor: AppColors.info,
                      title: 'Gestione Ordini',
                      description: 'Tipologie, limiti e tempi degli ordini',
                      onTap: () => setState(
                        () => _selectedSection = SettingsSection.orders,
                      ),
                    ),
                    _buildSettingCard(
                      width: itemWidth,
                      icon: Icons.delivery_dining_rounded,
                      iconColor: AppColors.warning,
                      title: 'Configurazione Consegne',
                      description: 'Costi, tempi e zone di consegna',
                      onTap: () => setState(
                        () => _selectedSection = SettingsSection.delivery,
                      ),
                    ),
                    _buildSettingCard(
                      width: itemWidth,
                      icon: Icons.palette_rounded,
                      iconColor: AppColors.accent,
                      title: 'Brand e Aspetto',
                      description: 'Colori e personalizzazione visiva',
                      onTap: () => setState(
                        () => _selectedSection = SettingsSection.branding,
                      ),
                    ),
                    _buildSettingCard(
                      width: itemWidth,
                      icon: Icons.restaurant_menu_rounded,
                      iconColor: AppColors.success,
                      title: 'Gestione Cucina',
                      description: 'Notifiche e preferenze cucina',
                      onTap: () => setState(
                        () => _selectedSection = SettingsSection.kitchen,
                      ),
                    ),
                    _buildSettingCard(
                      width: itemWidth,
                      icon: Icons.business_center_rounded,
                      iconColor: AppColors.primary,
                      title: 'Regole Business',
                      description: 'Orari e chiusure straordinarie',
                      onTap: () => setState(
                        () => _selectedSection = SettingsSection.business,
                      ),
                    ),
                    _buildSettingCard(
                      width: itemWidth,
                      icon: Icons.location_city_rounded,
                      iconColor: AppColors.error,
                      title: 'Gestione Città',
                      description: 'Zone e città di consegna',
                      onTap: () => setState(
                        () => _selectedSection = SettingsSection.cities,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  int _resolveColumns(double width) {
    if (width >= 1280) return 3;
    if (width >= 900) return 2;
    return 1;
  }

  Widget _buildSettingCard({
    required double width,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXL,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusXL,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusXL,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.radiusLG,
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Text(
                      'Configura',
                      style: AppTypography.labelMedium.copyWith(
                        color: iconColor,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: iconColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic settings) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final isActive =
        settings.businessRules?.attiva && settings.pizzeria?.attiva;

    return Container(
      padding: EdgeInsets.all(
        AppBreakpoints.responsive(
          context: context,
          mobile: AppSpacing.lg,
          tablet: AppSpacing.xl,
          desktop: AppSpacing.xxxl,
        ),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impostazioni',
                  style: isDesktop
                      ? AppTypography.headlineMedium
                      : AppTypography.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Seleziona una categoria per configurare la tua pizzeria',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusPill(isActive),
        ],
      ),
    );
  }

  Widget _buildStatusPill(bool isActive) {
    final color = isActive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusXL,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.pause_circle_filled,
            size: 18,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isActive ? 'Aperta' : 'Chiusa',
            style: AppTypography.labelMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Caricamento impostazioni...', style: AppTypography.titleMedium),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXXL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('Errore nel caricamento', style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Non siamo riusciti a caricare le impostazioni',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            ElevatedButton(
              onPressed: () => ref.refresh(pizzeriaSettingsProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxxl,
                  vertical: AppSpacing.lg,
                ),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
              ),
              child: Text(
                'Riprova',
                style: AppTypography.buttonMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXXL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.settings_rounded,
                size: 72,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Text(
              'Nessuna pizzeria trovata',
              style: AppTypography.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Contatta l\'amministratore per configurare la tua pizzeria',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
