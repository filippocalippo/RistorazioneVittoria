import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../DesignSystem/design_tokens.dart';
import '../../../core/models/pizzeria_model.dart';
import '../../../core/models/settings/business_rules_settings.dart';
import '../../../core/models/settings/delivery_configuration_settings.dart';
import '../../../core/models/settings/display_branding_settings.dart';
import '../../../core/models/settings/kitchen_management_settings.dart';
import '../../../core/models/settings/order_management_settings.dart';
import '../../../core/models/settings/pizzeria_settings_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/widgets/cached_network_image.dart';
import '../../../providers/pizzeria_settings_provider.dart';
import '../../../providers/organization_provider.dart';
import '../screens/settings_screen.dart';
import 'cities_management_section.dart';

class SettingsForm extends ConsumerStatefulWidget {
  final PizzeriaSettingsModel settings;
  final SettingsSection initialSection;
  final VoidCallback onBack;

  const SettingsForm({
    super.key,
    required this.settings,
    required this.initialSection,
    required this.onBack,
  });

  @override
  ConsumerState<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<SettingsForm> {
  final _generalFormKey = GlobalKey<FormState>();
  final _orderFormKey = GlobalKey<FormState>();
  final _deliveryFormKey = GlobalKey<FormState>();
  final _businessFormKey = GlobalKey<FormState>();

  late PizzeriaModel _pizzeria;
  late OrderManagementSettings _orderSettings;
  late DeliveryConfigurationSettings _deliverySettings;
  late DisplayBrandingSettings _brandingSettings;
  late KitchenManagementSettings _kitchenSettings;
  late BusinessRulesSettings _businessSettings;

  final Map<String, Map<String, dynamic>> _businessHoursDraft = {};

  late final TextEditingController _nomeController;
  late final TextEditingController _indirizzoController;
  late final TextEditingController _cittaController;
  late final TextEditingController _capController;
  late final TextEditingController _provinciaController;
  late final TextEditingController _telefonoController;
  late final TextEditingController _emailController;

  late final TextEditingController _ordineMinimoController;
  late final TextEditingController _tempoPreparazioneController;
  late final TextEditingController _capacityTakeawayPerSlotController;
  late final TextEditingController _capacityDeliveryPerSlotController;

  late final TextEditingController _costoConsegnaBaseController;
  late final TextEditingController _costoConsegnaPerKmController;
  late final TextEditingController _raggioConsegnaController;
  late final TextEditingController _consegnaGratuitaController;
  late final TextEditingController _tempoConsegnaMinController;
  late final TextEditingController _tempoConsegnaMaxController;

  late final TextEditingController _primaryColorController;
  late final TextEditingController _secondaryColorController;

  bool _savingGeneral = false;
  bool _savingOrder = false;
  bool _savingDelivery = false;
  bool _savingBranding = false;
  bool _savingKitchen = false;
  bool _savingBusiness = false;
  bool _isUploadingLogo = false;
  bool _isTogglingActive = false;

  late bool _isActive;
  late int _slotDuration;
  late String _calcoloConsegna;
  late bool _chiusuraTemporanea;
  DateTime? _dataChiusuraDa;
  DateTime? _dataChiusuraA;

  final ImagePicker _imagePicker = ImagePicker();

  static const List<int> _slotOptions = [15, 30, 60];
  static const List<String> _dayKeys = [
    'lunedi',
    'martedi',
    'mercoledi',
    'giovedi',
    'venerdi',
    'sabato',
    'domenica',
  ];
  static const List<String> _dayLabels = [
    'Lunedi',
    'Martedi',
    'Mercoledi',
    'Giovedi',
    'Venerdi',
    'Sabato',
    'Domenica',
  ];
  static const List<String> _colorOptions = [
    '#DC2626',
    '#EF4444',
    '#F97316',
    '#F59E0B',
    '#16A34A',
    '#059669',
    '#0EA5E9',
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#111827',
    '#6B7280',
  ];
  final RegExp _hexColorExp = RegExp(r'^#[0-9A-Fa-f]{6}$');

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController();
    _indirizzoController = TextEditingController();
    _cittaController = TextEditingController();
    _capController = TextEditingController();
    _provinciaController = TextEditingController();
    _telefonoController = TextEditingController();
    _emailController = TextEditingController();

    _ordineMinimoController = TextEditingController();
    _tempoPreparazioneController = TextEditingController();
    _capacityTakeawayPerSlotController = TextEditingController();
    _capacityDeliveryPerSlotController = TextEditingController();

    _costoConsegnaBaseController = TextEditingController();
    _costoConsegnaPerKmController = TextEditingController();
    _raggioConsegnaController = TextEditingController();
    _consegnaGratuitaController = TextEditingController();
    _tempoConsegnaMinController = TextEditingController();
    _tempoConsegnaMaxController = TextEditingController();

    _primaryColorController = TextEditingController();
    _secondaryColorController = TextEditingController();

    _syncFrom(widget.settings);
  }

  @override
  void didUpdateWidget(covariant SettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings != oldWidget.settings) {
      _syncFrom(widget.settings);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _indirizzoController.dispose();
    _cittaController.dispose();
    _capController.dispose();
    _provinciaController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();

    _ordineMinimoController.dispose();
    _tempoPreparazioneController.dispose();
    _capacityTakeawayPerSlotController.dispose();
    _capacityDeliveryPerSlotController.dispose();

    _costoConsegnaBaseController.dispose();
    _costoConsegnaPerKmController.dispose();
    _raggioConsegnaController.dispose();
    _consegnaGratuitaController.dispose();
    _tempoConsegnaMinController.dispose();
    _tempoConsegnaMaxController.dispose();

    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    super.dispose();
  }

  void _syncFrom(PizzeriaSettingsModel settings) {
    _pizzeria = settings.pizzeria;
    _orderSettings = settings.orderManagement;
    _deliverySettings = settings.deliveryConfiguration;
    _brandingSettings = settings.branding;
    _kitchenSettings = settings.kitchen;
    _businessSettings = settings.businessRules;
    _nomeController.text = _pizzeria.nome;
    _indirizzoController.text = _pizzeria.indirizzo ?? '';
    _cittaController.text = _pizzeria.citta ?? '';
    _capController.text = _pizzeria.cap ?? '';
    _provinciaController.text = _pizzeria.provincia ?? '';
    _telefonoController.text = _pizzeria.telefono ?? '';
    _emailController.text = _pizzeria.email ?? '';

    _ordineMinimoController.text = _formatDouble(_orderSettings.ordineMinimo);
    _tempoPreparazioneController.text = _orderSettings.tempoPreparazioneMedio
        .toString();

    // Fetch raw order management settings to hydrate capacity fields
    final db = DatabaseService();
    ref.read(currentOrganizationProvider.future).then((orgId) {
      return db.getOrderManagementSettingsRaw(organizationId: orgId);
    }).then((raw) {
        if (!mounted) return;
        final capTk = (raw?['capacity_takeaway_per_slot'] as int?) ?? 50;
        final capDl = (raw?['capacity_delivery_per_slot'] as int?) ?? 50;
        setState(() {
          _capacityTakeawayPerSlotController.text = capTk.toString();
          _capacityDeliveryPerSlotController.text = capDl.toString();
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _capacityTakeawayPerSlotController.text = '50';
          _capacityDeliveryPerSlotController.text = '50';
        });
      });

    _costoConsegnaBaseController.text = _formatDouble(
      _deliverySettings.costoConsegnaBase,
    );
    _costoConsegnaPerKmController.text = _formatDouble(
      _deliverySettings.costoConsegnaPerKm,
    );
    _raggioConsegnaController.text = _formatDouble(
      _deliverySettings.raggioConsegnaKm,
    );
    _consegnaGratuitaController.text = _formatDouble(
      _deliverySettings.consegnaGratuitaSopra,
    );
    _tempoConsegnaMinController.text = _deliverySettings.tempoConsegnaStimatoMin
        .toString();
    _tempoConsegnaMaxController.text = _deliverySettings.tempoConsegnaStimatoMax
        .toString();

    _primaryColorController.text = _brandingSettings.colorePrimario
        .toUpperCase();
    _secondaryColorController.text = _brandingSettings.coloreSecondario
        .toUpperCase();

    _isActive = _businessSettings.attiva && _pizzeria.attiva;
    _slotDuration = _orderSettings.tempoSlotMinuti;
    _calcoloConsegna = _deliverySettings.tipoCalcoloConsegna;
    _chiusuraTemporanea = _businessSettings.chiusuraTemporanea;
    _dataChiusuraDa = _businessSettings.dataChiusuraDa;
    _dataChiusuraA = _businessSettings.dataChiusuraA;

    _businessHoursDraft.clear();
  }

  @override
  Widget build(BuildContext context) {
    final padding = AppBreakpoints.responsive(
      context: context,
      mobile: AppSpacing.lg,
      tablet: AppSpacing.xl,
      desktop: AppSpacing.xxxl,
    );

    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: _buildSectionContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent() {
    switch (widget.initialSection) {
      case SettingsSection.general:
        return _buildGeneralInfoCard();
      case SettingsSection.orders:
        return _buildOrderManagementCard();
      case SettingsSection.delivery:
        return _buildDeliveryConfigurationCard();
      case SettingsSection.branding:
        return _buildBrandingCard();
      case SettingsSection.kitchen:
        return _buildKitchenCard();
      case SettingsSection.business:
        return _buildBusinessRulesCard();
      case SettingsSection.cities:
        return const CitiesManagementSection();
    }
  }

  Widget _buildHeader(BuildContext context) {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final sectionTitle = _getSectionTitle();
    
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
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Torna alle impostazioni',
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sectionTitle,
                  style: isDesktop
                      ? AppTypography.headlineMedium
                      : AppTypography.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Configura le impostazioni per questa sezione',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusPill(),
        ],
      ),
    );
  }

  String _getSectionTitle() {
    switch (widget.initialSection) {
      case SettingsSection.general:
        return 'Informazioni Generali';
      case SettingsSection.orders:
        return 'Gestione Ordini';
      case SettingsSection.delivery:
        return 'Configurazione Consegne';
      case SettingsSection.branding:
        return 'Brand e Aspetto';
      case SettingsSection.kitchen:
        return 'Gestione Cucina';
      case SettingsSection.business:
        return 'Regole Business';
      case SettingsSection.cities:
        return 'Gestione Città';
    }
  }

  Widget _buildStatusPill() {
    final color = _isActive ? AppColors.success : AppColors.error;
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
            _isActive ? Icons.check_circle_rounded : Icons.pause_circle_filled,
            size: 18,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _isActive ? 'Aperta' : 'Chiusa',
            style: AppTypography.labelMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralInfoCard() {
    return _SettingsCategoryCard(
      icon: Icons.store_rounded,
      iconColor: AppColors.primary,
      title: 'Informazioni Generali',
      description: 'Dati principali visibili ai clienti',
      actions: [
        _buildSaveButton(
          label: 'Salva informazioni',
          loading: _savingGeneral,
          onPressed: _saveGeneralInfo,
        ),
      ],
      child: Form(
        key: _generalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLogoUploader(),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: _nomeController,
              decoration: _fieldDecoration(
                label: 'Nome Pizzeria',
                icon: Icons.local_pizza_outlined,
              ).copyWith(
                helperText: 'Il nome è configurato nelle costanti dell\'app',
                helperStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              enabled: false,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildActiveSwitch(),
            const Divider(height: AppSpacing.xxxl),
            Text(
              'Contatti e indirizzo',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: AppTypography.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _indirizzoController,
              decoration: _fieldDecoration(
                label: 'Indirizzo',
                icon: Icons.location_on_outlined,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cittaController,
                    decoration: _fieldDecoration(
                      label: 'Citta',
                      icon: Icons.apartment_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: _capController,
                    decoration: _fieldDecoration(
                      label: 'CAP',
                      icon: Icons.pin_drop_outlined,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: _provinciaController,
                    decoration: _fieldDecoration(
                      label: 'Provincia',
                      icon: Icons.map_outlined,
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _telefonoController,
                    decoration: _fieldDecoration(
                      label: 'Telefono',
                      icon: Icons.phone_rounded,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    decoration: _fieldDecoration(
                      label: 'Email',
                      icon: Icons.email_outlined,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final emailReg = RegExp(
                        r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                      );
                      if (!emailReg.hasMatch(value)) {
                        return 'Formato email non valido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoUploader() {
    final logoUrl = _pizzeria.logoUrl;
    return Row(
      children: [
        ClipRRect(
          borderRadius: AppRadius.radiusXXL,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: AppRadius.radiusXXL,
              border: Border.all(color: AppColors.border),
            ),
            child: logoUrl.isNotEmpty
                ? CachedNetworkImageWidget.logo(
                    imageUrl: logoUrl,
                    size: 120,
                    borderRadius: AppRadius.radiusXXL,
                  )
                : Icon(
                    Icons.storefront_rounded,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Logo della pizzeria',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Carica un logo quadrato (PNG o JPG, max 5MB)',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _isUploadingLogo ? null : _uploadLogo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusLG,
                  ),
                ),
                icon: _isUploadingLogo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.upload_rounded, size: 18),
                label: Text(
                  _isUploadingLogo ? 'Caricamento...' : 'Carica nuovo logo',
                  style: AppTypography.buttonMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSwitch() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: (_isActive ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.15),
              borderRadius: AppRadius.radiusLG,
            ),
            child: Icon(
              _isActive ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: _isActive ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stato pizzeria',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isActive
                      ? 'La pizzeria accetta ordini online'
                      : 'La pizzeria e temporaneamente chiusa',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isActive,
            onChanged: _isTogglingActive ? null : _toggleActive,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderManagementCard() {
    return _SettingsCategoryCard(
      icon: Icons.receipt_long_rounded,
      iconColor: AppColors.info,
      title: 'Gestione Ordini',
      description: 'Configura tipologie e limiti degli ordini',
      actions: [
        _buildSaveButton(
          label: 'Salva gestione ordini',
          loading: _savingOrder,
          onPressed: _saveOrderManagement,
        ),
      ],
      child: Form(
        key: _orderFormKey,
        child: Column(
          children: [
            _buildSubsectionTitle('Tipi di ordine'),
            _buildSwitchTile(
              title: 'Consegna a domicilio',
              subtitle: 'Consenti gli ordini con consegna',
              value: _orderSettings.ordiniConsegnaAttivi,
              onChanged: (v) => setState(() {
                _orderSettings = _orderSettings.copyWith(
                  ordiniConsegnaAttivi: v,
                );
              }),
            ),
            _buildSwitchTile(
              title: 'Asporto',
              subtitle: 'Permetti il ritiro in pizzeria',
              value: _orderSettings.ordiniAsportoAttivi,
              onChanged: (v) => setState(() {
                _orderSettings = _orderSettings.copyWith(
                  ordiniAsportoAttivi: v,
                );
              }),
            ),
            const Divider(height: AppSpacing.xxxl),
            _buildSubsectionTitle('Metodi di pagamento accettati'),
            _buildSwitchTile(
              title: 'Pagamenti in contanti',
              subtitle: 'Accetta pagamenti in contanti alla consegna/ritiro',
              value: _orderSettings.accettaPagamentiContanti,
              onChanged: (v) => setState(() {
                _orderSettings = _orderSettings.copyWith(
                  accettaPagamentiContanti: v,
                );
              }),
            ),
            _buildSwitchTile(
              title: 'Pagamenti con carta',
              subtitle: 'Accetta pagamenti con carta di credito/debito',
              value: _orderSettings.accettaPagamentiCarta,
              onChanged: (v) => setState(() {
                _orderSettings = _orderSettings.copyWith(
                  accettaPagamentiCarta: v,
                );
              }),
            ),
            const Divider(height: AppSpacing.xxxl),
            _buildSubsectionTitle('Limiti e tempi'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ordineMinimoController,
                    decoration: _fieldDecoration(
                      label: 'Ordine minimo (€)',
                      icon: Icons.euro_rounded,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: TextFormField(
                    controller: _tempoPreparazioneController,
                    decoration: _fieldDecoration(
                      label: 'Tempo prep. medio (min)',
                      icon: Icons.timer_outlined,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _capacityTakeawayPerSlotController,
                    decoration: _fieldDecoration(
                      label: 'Articoli asporto per slot',
                      icon: Icons.shopping_bag_outlined,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final val = int.tryParse((v ?? '').trim());
                      if (val == null || val <= 0) return 'Valore > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: TextFormField(
                    controller: _capacityDeliveryPerSlotController,
                    decoration: _fieldDecoration(
                      label: 'Articoli consegna per slot',
                      icon: Icons.delivery_dining_rounded,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final val = int.tryParse((v ?? '').trim());
                      if (val == null || val <= 0) return 'Valore > 0';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<int>(
              decoration: _fieldDecoration(
                label: 'Durata slot (minuti)',
                icon: Icons.view_week_rounded,
              ),
              initialValue: _slotDuration,
              items: _slotOptions
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text('$v minuti'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _slotDuration = value);
              },
            ),
            const Divider(height: AppSpacing.xxxl),
            _buildWarningTile(
              active: _orderSettings.pausaOrdiniAttiva,
              title: 'Pausa ordini',
              description:
                  'Quando attiva, i clienti non possono creare nuovi ordini.',
              onChanged: (v) => setState(() {
                _orderSettings = _orderSettings.copyWith(pausaOrdiniAttiva: v);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryConfigurationCard() {
    final isCalcoloFisso = _calcoloConsegna == 'fisso';
    return _SettingsCategoryCard(
      icon: Icons.delivery_dining_rounded,
      iconColor: AppColors.warning,
      title: 'Configurazione Consegne',
      description: 'Costi, tempi e promozioni delle consegne',
      actions: [
        _buildSaveButton(
          label: 'Salva configurazione consegne',
          loading: _savingDelivery,
          onPressed: _saveDeliveryConfiguration,
        ),
      ],
      child: Form(
        key: _deliveryFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubsectionTitle('Metodo di calcolo'),
            _buildRadioTile(
              title: 'Prezzo fisso',
              subtitle: 'Stesso costo per tutte le consegne',
              value: 'fisso',
              groupValue: _calcoloConsegna,
              onChanged: (v) => setState(() => _calcoloConsegna = v),
            ),
            _buildRadioTile(
              title: 'Per chilometro',
              subtitle: 'Costo calcolato in base alla distanza',
              value: 'per_km',
              groupValue: _calcoloConsegna,
              onChanged: (v) => setState(() => _calcoloConsegna = v),
            ),
            const Divider(height: AppSpacing.xxxl),
            _buildSubsectionTitle('Costi'),
            if (isCalcoloFisso)
              TextFormField(
                controller: _costoConsegnaBaseController,
                decoration: _fieldDecoration(
                  label: 'Costo consegna (€)',
                  icon: Icons.euro_rounded,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costoConsegnaPerKmController,
                      decoration: _fieldDecoration(
                        label: 'Costo per km (€)',
                        icon: Icons.alt_route_rounded,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: TextFormField(
                      controller: _raggioConsegnaController,
                      decoration: _fieldDecoration(
                        label: 'Raggio massimo (km)',
                        icon: Icons.social_distance_rounded,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
            const Divider(height: AppSpacing.xxxl),
            _buildSubsectionTitle('Promozioni'),
            TextFormField(
              controller: _consegnaGratuitaController,
              decoration: _fieldDecoration(
                label: 'Consegna gratuita sopra (€)',
                icon: Icons.local_offer_outlined,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const Divider(height: AppSpacing.xxxl),
            _buildSubsectionTitle('Tempi di consegna'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tempoConsegnaMinController,
                    decoration: _fieldDecoration(
                      label: 'Tempo minimo (min)',
                      icon: Icons.timer_outlined,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: TextFormField(
                    controller: _tempoConsegnaMaxController,
                    decoration: _fieldDecoration(
                      label: 'Tempo massimo (min)',
                      icon: Icons.timer_rounded,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xxxl),
            _buildAdvancedCard(
              title: 'Zone personalizzate',
              description:
                  'Configura zone con costi di consegna differenti. Disponibile presto.',
              icon: Icons.layers_rounded,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Gestione zone personalizzate in arrivo. Contattaci per attivarla.',
                    ),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingCard() {
    return _SettingsCategoryCard(
      icon: Icons.palette_rounded,
      iconColor: AppColors.accent,
      title: 'Brand e Aspetto',
      description: 'Colori e impostazioni visive della piattaforma',
      actions: [
        _buildSaveButton(
          label: 'Salva branding',
          loading: _savingBranding,
          onPressed: _saveBranding,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSwitchTile(
            title: 'Mostra allergeni',
            subtitle: 'Visualizza informazioni sugli allergeni nei prodotti',
            value: _brandingSettings.mostraAllergeni,
            onChanged: (value) => setState(() {
              _brandingSettings = _brandingSettings.copyWith(
                mostraAllergeni: value,
              );
            }),
          ),
          const Divider(height: AppSpacing.xxxl),
          _buildSubsectionTitle('Palette colori'),
          const SizedBox(height: AppSpacing.md),
          _buildColorField(
            label: 'Colore primario',
            controller: _primaryColorController,
            onPick: () => _pickColor(
              title: 'Seleziona colore primario',
              initialValue: _primaryColorController.text,
              onSelected: (value) => setState(() {
                _primaryColorController.text = value;
                _brandingSettings = _brandingSettings.copyWith(
                  colorePrimario: value,
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildColorField(
            label: 'Colore secondario',
            controller: _secondaryColorController,
            onPick: () => _pickColor(
              title: 'Seleziona colore secondario',
              initialValue: _secondaryColorController.text,
              onSelected: (value) => setState(() {
                _secondaryColorController.text = value;
                _brandingSettings = _brandingSettings.copyWith(
                  coloreSecondario: value,
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildColorPreview(),
        ],
      ),
    );
  }

  Widget _buildColorField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onPick,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: _fieldDecoration(
              label: label,
              icon: Icons.color_lens_outlined,
            ),
            inputFormatters: [UpperCaseTextFormatter()],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _parseColor(controller.text),
            borderRadius: AppRadius.radiusLG,
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: onPick,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLG),
          ),
          icon: const Icon(Icons.palette_rounded, size: 18),
          label: const Text('Scegli'),
        ),
      ],
    );
  }

  Widget _buildColorPreview() {
    final primary = _parseColor(_primaryColorController.text);
    final secondary = _parseColor(_secondaryColorController.text);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.radiusLG,
        gradient: LinearGradient(colors: [primary, secondary]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anteprima',
            style: AppTypography.titleSmall.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ecco come appariranno i colori nell\'app.',
            style: AppTypography.bodySmall.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildKitchenCard() {
    return _SettingsCategoryCard(
      icon: Icons.restaurant_menu_rounded,
      iconColor: AppColors.success,
      title: 'Gestione Cucina',
      description: 'Notifiche e preferenze per il personale di cucina',
      actions: [
        _buildSaveButton(
          label: 'Salva impostazioni cucina',
          loading: _savingKitchen,
          onPressed: _saveKitchen,
        ),
      ],
      child: Column(
        children: [
          _buildSwitchTile(
            title: 'Stampa automatica ordini',
            subtitle: 'Invia automaticamente gli ordini alla stampante',
            value: _kitchenSettings.stampaAutomaticaOrdini,
            onChanged: (value) => setState(() {
              _kitchenSettings = _kitchenSettings.copyWith(
                stampaAutomaticaOrdini: value,
              );
            }),
          ),
          _buildSwitchTile(
            title: 'Mostra note in cucina',
            subtitle: 'Visualizza le note dei clienti negli ordini',
            value: _kitchenSettings.mostraNoteCucina,
            onChanged: (value) => setState(() {
              _kitchenSettings = _kitchenSettings.copyWith(
                mostraNoteCucina: value,
              );
            }),
          ),
          _buildSwitchTile(
            title: 'Alert sonoro nuovi ordini',
            subtitle: 'Riproduci un suono quando arriva un nuovo ordine',
            value: _kitchenSettings.alertSonoroNuovoOrdine,
            onChanged: (value) => setState(() {
              _kitchenSettings = _kitchenSettings.copyWith(
                alertSonoroNuovoOrdine: value,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessRulesCard() {
    final orari = _pizzeria.orari ?? {};
    return _SettingsCategoryCard(
      icon: Icons.business_center_rounded,
      iconColor: AppColors.primary,
      title: 'Regole Business',
      description: 'Orari di apertura e chiusure straordinarie',
      actions: [
        _buildSaveButton(
          label: 'Salva regole business',
          loading: _savingBusiness,
          onPressed: _saveBusinessRules,
        ),
      ],
      child: Form(
        key: _businessFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubsectionTitle('Orari di apertura'),
            const SizedBox(height: AppSpacing.md),
            ...List.generate(_dayKeys.length, (index) {
              final key = _dayKeys[index];
              final label = _dayLabels[index];
              final existing = orari[key] as Map<String, dynamic>? ?? {};
              final override = _businessHoursDraft[key];
              final isOpen = override != null
                  ? override['aperto'] as bool
                  : (existing['aperto'] as bool? ?? false);
              final start = override != null
                  ? override['apertura'] as String
                  : (existing['apertura'] as String? ?? '12:00');
              final end = override != null
                  ? override['chiusura'] as String
                  : (existing['chiusura'] as String? ?? '23:00');

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: AppRadius.radiusLG,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          label,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: AppTypography.semiBold,
                          ),
                        ),
                      ),
                      Switch(
                        value: isOpen,
                        onChanged: (value) =>
                            _updateBusinessHour(key, value, start, end),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      if (isOpen)
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildTimeField(
                                  label: 'Apertura',
                                  value: start,
                                  onChanged: (value) => _updateBusinessHour(
                                    key,
                                    true,
                                    value,
                                    end,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              Expanded(
                                child: _buildTimeField(
                                  label: 'Chiusura',
                                  value: end,
                                  onChanged: (value) => _updateBusinessHour(
                                    key,
                                    true,
                                    start,
                                    value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Expanded(
                          child: Text(
                            'Chiuso',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const Divider(height: AppSpacing.xxxl),
            _buildSubsectionTitle('Chiusura temporanea'),
            _buildSwitchTile(
              title: 'Imposta chiusura temporanea',
              subtitle: 'Ferma gli ordini per un periodo specifico',
              value: _chiusuraTemporanea,
              onChanged: (value) => setState(() {
                _chiusuraTemporanea = value;
              }),
            ),
            if (_chiusuraTemporanea) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      label: 'Data inizio',
                      value: _dataChiusuraDa,
                      onTap: () => _pickDate(
                        current: _dataChiusuraDa,
                        onSelected: (value) => setState(() {
                          _dataChiusuraDa = value;
                          if (_dataChiusuraA != null &&
                              value != null &&
                              value.isAfter(_dataChiusuraA!)) {
                            _dataChiusuraA = value;
                          }
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _buildDateField(
                      label: 'Data fine',
                      value: _dataChiusuraA,
                      onTap: () => _pickDate(
                        current: _dataChiusuraA,
                        onSelected: (value) => setState(() {
                          _dataChiusuraA = value;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubsectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: AppTypography.titleSmall.copyWith(
          fontWeight: AppTypography.bold,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildWarningTile({
    required bool active,
    required String title,
    required String description,
    required ValueChanged<bool> onChanged,
  }) {
    final color = active ? AppColors.warning : AppColors.border;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.radiusLG,
        border: Border.all(color: color.withValues(alpha: 0.6)),
        color: color.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: AppTypography.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(color: color),
                ),
              ],
            ),
          ),
          Switch(value: active, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLG,
        border: Border.all(
          color: value == groupValue
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.radiusLG,
        onTap: () => onChanged(value),
        child: Row(
          children: [
            Icon(
              value == groupValue
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: value == groupValue
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLG),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: AppTypography.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: AppRadius.radiusLG),
    );
  }

  Widget _buildTimeField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final selected = await _selectTime(value);
        if (selected != null) {
          onChanged(selected);
        }
      },
      borderRadius: AppRadius.radiusLG,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.radiusLG,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text('$label $value', style: AppTypography.bodyMedium),
            ),
            Icon(Icons.edit_rounded, color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final text = value != null
        ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
        : 'Seleziona';
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusLG,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.radiusLG,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text('$label: $text', style: AppTypography.bodyMedium),
            ),
            Icon(
              Icons.edit_calendar_rounded,
              color: AppColors.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton({
    required String label,
    required bool loading,
    required Future<void> Function() onPressed,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save_rounded),
        label: Text(
          loading ? 'Salvataggio...' : label,
          style: AppTypography.buttonMedium.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _saveGeneralInfo() async {
    if (!_generalFormKey.currentState!.validate()) return;

    setState(() => _savingGeneral = true);
    try {
      final updates = {
        // 'nome' is now hardcoded via AppConstants.pizzeriaName
        'indirizzo': _indirizzoController.text.trim().isEmpty
            ? null
            : _indirizzoController.text.trim(),
        'citta': _cittaController.text.trim().isEmpty
            ? null
            : _cittaController.text.trim(),
        'cap': _capController.text.trim().isEmpty
            ? null
            : _capController.text.trim(),
        'provincia': _provinciaController.text.trim().isEmpty
            ? null
            : _provinciaController.text.trim().toUpperCase(),
        'telefono': _telefonoController.text.trim().isEmpty
            ? null
            : _telefonoController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
      };

      await ref.read(pizzeriaSettingsProvider.notifier).updatePizzeria(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informazioni generali aggiornate'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il salvataggio: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingGeneral = false);
    }
  }

  Future<void> _saveOrderManagement() async {
    if (!_orderFormKey.currentState!.validate()) return;

    setState(() => _savingOrder = true);
    try {
      final values = <String, dynamic>{
        'ordini_consegna_attivi': _orderSettings.ordiniConsegnaAttivi,
        'ordini_asporto_attivi': _orderSettings.ordiniAsportoAttivi,
        'ordini_tavolo_attivi': _orderSettings.ordiniTavoloAttivi,
        'ordine_minimo': _parseDouble(
          _ordineMinimoController.text.trim(),
          fallback: _orderSettings.ordineMinimo,
        ),
        'tempo_preparazione_medio': _parseInt(
          _tempoPreparazioneController.text.trim(),
          fallback: _orderSettings.tempoPreparazioneMedio,
        ),
        'tempo_slot_minuti': _slotDuration,
        'pausa_ordini_attiva': _orderSettings.pausaOrdiniAttiva,
        'accetta_pagamenti_contanti': _orderSettings.accettaPagamentiContanti,
        'accetta_pagamenti_carta': _orderSettings.accettaPagamentiCarta,
        'capacity_takeaway_per_slot': _parseInt(
          _capacityTakeawayPerSlotController.text.trim(),
          fallback: 50,
        ),
        'capacity_delivery_per_slot': _parseInt(
          _capacityDeliveryPerSlotController.text.trim(),
          fallback: 50,
        ),
      };

      await ref
          .read(pizzeriaSettingsProvider.notifier)
          .saveOrderManagementRaw(values);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gestione ordini aggiornata'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il salvataggio: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  Future<void> _saveDeliveryConfiguration() async {
    if (!_deliveryFormKey.currentState!.validate()) return;

    setState(() => _savingDelivery = true);
    try {
      final updated = DeliveryConfigurationSettings(
        tipoCalcoloConsegna: _calcoloConsegna,
        costoConsegnaBase: _parseDouble(
          _costoConsegnaBaseController.text.trim(),
          fallback: _deliverySettings.costoConsegnaBase,
        ),
        costoConsegnaPerKm: _parseDouble(
          _costoConsegnaPerKmController.text.trim(),
          fallback: _deliverySettings.costoConsegnaPerKm,
        ),
        raggioConsegnaKm: _parseDouble(
          _raggioConsegnaController.text.trim(),
          fallback: _deliverySettings.raggioConsegnaKm,
        ),
        consegnaGratuitaSopra: _parseDouble(
          _consegnaGratuitaController.text.trim(),
          fallback: _deliverySettings.consegnaGratuitaSopra,
        ),
        tempoConsegnaStimatoMin: _parseInt(
          _tempoConsegnaMinController.text.trim(),
          fallback: _deliverySettings.tempoConsegnaStimatoMin,
        ),
        tempoConsegnaStimatoMax: _parseInt(
          _tempoConsegnaMaxController.text.trim(),
          fallback: _deliverySettings.tempoConsegnaStimatoMax,
        ),
        zoneConsegnaPersonalizzate:
            _deliverySettings.zoneConsegnaPersonalizzate,
      );

      await ref
          .read(pizzeriaSettingsProvider.notifier)
          .saveDeliveryConfiguration(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurazione consegne aggiornata'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il salvataggio: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingDelivery = false);
    }
  }

  Future<void> _saveBranding() async {
    setState(() => _savingBranding = true);
    try {
      final primary = _primaryColorController.text.trim();
      final secondary = _secondaryColorController.text.trim();

      if (!_hexColorExp.hasMatch(primary) ||
          !_hexColorExp.hasMatch(secondary)) {
        throw Exception('Inserisci colori validi in formato esadecimale');
      }

      final updated = _brandingSettings.copyWith(
        colorePrimario: primary,
        coloreSecondario: secondary,
      );

      await ref.read(pizzeriaSettingsProvider.notifier).saveBranding(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Brand aggiornato'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il salvataggio: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingBranding = false);
    }
  }

  Future<void> _saveKitchen() async {
    setState(() => _savingKitchen = true);
    try {
      await ref
          .read(pizzeriaSettingsProvider.notifier)
          .saveKitchen(_kitchenSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impostazioni cucina aggiornate'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il salvataggio: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingKitchen = false);
    }
  }

  Future<void> _saveBusinessRules() async {
    if (_chiusuraTemporanea) {
      if (_dataChiusuraDa == null || _dataChiusuraA == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seleziona le date di chiusura'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (_dataChiusuraDa!.isAfter(_dataChiusuraA!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La data di inizio deve precedere la data di fine'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _savingBusiness = true);
    try {
      if (_businessHoursDraft.isNotEmpty) {
        final merged = Map<String, dynamic>.from(_pizzeria.orari ?? {});
        merged.addAll(_businessHoursDraft);
        await ref
            .read(pizzeriaSettingsProvider.notifier)
            .updateBusinessHours(merged);
        _businessHoursDraft.clear();
      }

      final updated = _businessSettings.copyWith(
        chiusuraTemporanea: _chiusuraTemporanea,
        dataChiusuraDa: _chiusuraTemporanea ? _dataChiusuraDa : null,
        dataChiusuraA: _chiusuraTemporanea ? _dataChiusuraA : null,
      );

      await ref
          .read(pizzeriaSettingsProvider.notifier)
          .saveBusinessRules(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Regole business aggiornate'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il salvataggio: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingBusiness = false);
    }
  }

  Future<void> _toggleActive(bool value) async {
    setState(() => _isTogglingActive = true);
    try {
      await ref.read(pizzeriaSettingsProvider.notifier).toggleActive(value);
      if (mounted) {
        setState(() => _isActive = value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'Pizzeria attivata' : 'Pizzeria disattivata'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore aggiornamento stato: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingActive = false);
    }
  }

  Future<void> _pickColor({
    required String title,
    required String initialValue,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXL),
          title: Text(title),
          content: SizedBox(
            width: 320,
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: _colorOptions
                  .map(
                    (hex) => GestureDetector(
                      onTap: () => Navigator.of(context).pop(hex),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _parseColor(hex),
                          borderRadius: AppRadius.radiusLG,
                          border: Border.all(
                            color:
                                hex.toUpperCase() == initialValue.toUpperCase()
                                ? AppColors.primary
                                : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla'),
            ),
          ],
        );
      },
    );

    if (selected != null) {
      onSelected(selected.toUpperCase());
    }
  }

  Future<void> _uploadLogo() async {
    try {
      File? file;

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result == null || result.files.isEmpty) return;
        final path = result.files.first.path;
        if (path == null) throw Exception('Percorso file non disponibile');
        file = File(path);
      } else {
        final image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (image == null) return;
        file = File(image.path);
      }

      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Il file e troppo grande (max 5MB)'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      setState(() => _isUploadingLogo = true);

      // Logo is now hardcoded, no need to upload to storage
      // The logoUrl getter returns AppConstants.pizzeriaLogo

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo aggiornato con successo'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il caricamento: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onSelected,
  }) async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    onSelected(result);
  }

  Future<String?> _selectTime(String initial) async {
    final parts = initial.split(':');
    final hour = int.tryParse(parts.first) ?? 12;
    final minute = int.tryParse(parts.last) ?? 0;

    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );

    if (result == null) return null;
    final formatted =
        '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}';
    return formatted;
  }

  void _updateBusinessHour(String key, bool isOpen, String start, String end) {
    setState(() {
      _businessHoursDraft[key] = {
        'aperto': isOpen,
        'apertura': start,
        'chiusura': end,
      };
    });
  }

  double _parseDouble(String input, {required double fallback}) {
    final value = double.tryParse(input.replaceAll(',', '.'));
    return value ?? fallback;
  }

  int _parseInt(String input, {required int fallback}) {
    final value = int.tryParse(input);
    return value ?? fallback;
  }

  String _formatDouble(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  Color _parseColor(String hex) {
    if (!_hexColorExp.hasMatch(hex)) {
      return AppColors.primary;
    }
    final buffer = StringBuffer();
    if (hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class _SettingsCategoryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<Widget>? actions;
  final Widget child;

  const _SettingsCategoryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusXXL,
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.radiusLG,
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          child,
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxxl),
            ...actions!,
          ],
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
